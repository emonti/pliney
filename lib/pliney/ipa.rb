require 'rubygems'
require 'zip'
require 'pliney/util'
require 'pliney/entitlements'

module Pliney
    class IPA
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
    end
end
