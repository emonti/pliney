require 'rubygems'
require 'zip'
require_relative 'util'
require_relative 'macho'
require_relative 'apple_code_signature'

module Pliney
    class IPA
        class ZipExtractError < StandardError
        end

        SYSTEM_HAS_UNZIP = system("which unzip > /dev/null")

        def self.from_path(path)
            ipa = new(Zip::File.open(path))
            if block_given?
                ret = yield(ipa)
                ipa.close
                return ret
            else
                return ipa
            end
        end

        # TODO - creating an ipa from scratch?
        # def self.create(path)
        #    new(Zip::File.open(path, Zip::File::CREATE))
        # end

        attr_reader :zipfile

        def initialize(zipfile)
            @zipfile = zipfile
        end

        def appdir
            @appdir ||= find_appdir
        end

        def parse_plist_entry(path)
            Pliney.parse_plist(read_path(path))
        end

        def find_appdir
            if e = @zipfile.find{|ent| ent.directory? and ent.name =~ /^Payload\/[^\/]*\.app\/$/ }
                return Pathname(e.name)
            end
        end

        def read_path(path, *args)
            return @zipfile.get_input_stream(path.to_s){|sio| sio.read(*args)}
        end

        def info_plist
            return parse_plist_entry(appdir.join("Info.plist"))
        end

        def bundle_identifier
            return info_plist["CFBundleIdentifier"]
        end

        def bundle_version
            return info_plist["CFBundleVersion"]
        end

        def bundle_short_version
            return info_plist["CFBundleShortVersionString"]
        end

        def executable_path
            return appdir.join(info_plist["CFBundleExecutable"])
        end

        def executable_entry
            return get_entry(executable_path)
        end

        def ls
            return @zipfile.entries.map{|e| e.name}
        end

        def close
            @zipfile.close
        end

        def get_entry(path)
            return @zipfile.find_entry(path.to_s)
        end

        def provisioning_profile
            begin
                profile_data = read_path(appdir.join("embedded.mobileprovision"))
            rescue Errno::ENOENT
                return nil
            end

            ProvisioningProfile.from_asn1(profile_data)
        end

        def with_macho_for_entry(file_entry)
            with_extracted_tmpfile(file_entry) do |tmpfile|
                yield ::Pliney::MachO.from_stream(tmpfile)
            end
        end

        def with_executable_macho(&block)
            with_macho_for_entry(self.executable_entry, &block)
        end

        def codesignature_for_entry(file_entry)
            _with_tmpdir do |tmp_path|
                tmpf = tmp_path.join("executable")
                file_entry.extract(tmpf.to_s)
                return ::Pliney::AppleCodeSignature.from_path(tmpf.to_s)
            end
        end

        def executable_codesignature
            return codesignature_for_entry(self.executable_entry)
        end

        def entitlements_data_for_entry(file_entry)
            cs = self.codesignature_for_entry(file_entry)
            if cs
                ents_blob = cs.contents.find{|c| c.is_a? ::Pliney::AppleCodeSignature::Entitlement}
                if ents_blob
                    return ents_blob.data
                end
            end
        end

        def entitlements_for_entry(file_entry)
            dat = entitlements_data_for_entry(file_entry)
            if dat
                return ::Pliney.parse_plist(dat)
            end
        end

        def executable_entitlements_data
            return entitlements_data_for_entry(self.executable_entry)
        end

        def executable_entitlements
            return entitlements_for_entry(self.executable_entry)
        end

        def team_identifier
            entitlements = executable_entitlements()
            if entitlements
                return entitlements["com.apple.developer.team-identifier"]
            end
        end

        def extract(path)
            if SYSTEM_HAS_UNZIP
                ret = system("unzip", "-qd", path.to_s, self.zipfile.name.to_s)
                unless ret
                    raise(ZipExtractError, "'unzip' command returned non-zero status: #{$?.inspect}")
                end
            else
                path = Pathname(path)
                zipfile.each do |ent|
                    extract_path = path.join(ent.name)
                    FileUtils.mkdir_p(extract_path.dirname)
                    ent.extract(extract_path.to_s)
                    extract_path.chmod(ent.unix_perms & 0777)
                end
            end
            return path
        end

        def with_extracted_tmpdir(&block)
            _with_tmpdir {|tmp_path| yield(extract(tmp_path)) }
        end

        def with_extracted_tmpfile(ent, &block)
            tmpf = Tempfile.new("ent")
            begin
                Zip::IOExtras.copy_stream(tmpf, ent.get_input_stream)
                tmpf.rewind
                yield(tmpf)
            ensure
                tmpf.unlink()
            end
        end

        def each_file_entry
            zipfile.entries.select do |ent|
                not ent.name_is_directory?
            end.each do |ent|
                yield(ent)
            end
            return nil
        end

        def each_executable_entry
            each_file_entry do |entry|
                next if (zipstream = entry.get_input_stream).nil?
                next if (magicbytes = zipstream.read(4)).nil?
                next if (magic = magicbytes.unpack("N").first).nil?
                if ::Pliney::MachO::is_macho_magic(magic) or ::Pliney::MachO::is_fat_magic(magic)
                    yield(entry)
                end
            end
        end

        def executable_entries
            a = []
            each_executable_entry{|e| a << e}
            return a
        end

        def canonical_name
            return "#{self.team_identifier}.#{self.bundle_identifier}.v#{self.bundle_short_version}"
        end

        private

        def _with_tmpdir
            Dir.mktmpdir {|tmpd| yield(Pathname(tmpd)) }
        end
    end
end
