require_relative 'io_helpers'
require_relative 'apple_code_signature'

# Note this implementation only works with little-endian mach-o binaries
# such as ARM and X86. Older PPC mach-o files are big-endian. Support could
# be pretty easily added just by conditionally swapping in the IOHelper addons
# for read_uintXXbe instead of read_uintXXle where appropriate

module Pliney
    module MachO
        FAT_MAGIC = 0xCAFEBABE
        MACHO_MAGIC32 = 0xCEFAEDFE
        MACHO_MAGIC64 = 0xCFFAEDFE

        LC_REQ_DYLD = 0x80000000

        def self.is_fat_magic(magicval)
            return (magicval == FAT_MAGIC)
        end

        def self.is_macho_magic(magicval)
            return (is_macho32_magic(magicval) or is_macho64_magic(magicval))
        end

        def self.is_macho32_magic(magicval)
            return (magicval == MACHO_MAGIC32)
        end

        def self.is_macho64_magic(magicval)
            return (magicval == MACHO_MAGIC64)
        end

        def self.lcmap
            @LCMAP ||= Hash[
                LoadCommandConst.constants.map do |lc|
                    [lc, LoadCommandConst.const_get(lc)] 
                end
            ]
        end

        def self.resolve_lc(lcnum)
            lcmap.invert[lcnum]
        end

        def self.reader_for_lc(lcnum)
            lcsym = lcmap.invert[lcnum]
            if lcsym
                klname = "#{lcsym}_Reader"
                if MachO.const_defined?(klname)
                    return MachO.const_get(klname)
                end
            end
            return UndefinedLCReader
        end

        def self.reader_for_filemagic(magic)
            case magic
            when FAT_MAGIC
                return FatHeaderReader
            when MACHO_MAGIC32
                return MachHeaderReader
            when MACHO_MAGIC64
                return MachHeader64Reader
            else
                raise(ReaderError, "Unrecognized magic value: 0x%0.8x" % magic)
            end
        end

        def self.read_stream(fh)
            magic = fh.read_uint32
            fh.pos -= 4
            return reader_for_filemagic(magic).parse(fh)
        end
        singleton_class.send(:alias_method, :from_stream, :read_stream)

        module LoadCommandConst
            LC_SEGMENT = 0x1
            LC_SYMTAB = 0x2
            LC_SYMSEG = 0x3
            LC_THREAD = 0x4
            LC_UNIXTHREAD = 0x5
            LC_LOADFVMLIB = 0x6
            LC_IDFVMLIB = 0x7
            LC_IDENT = 0x8
            LC_FVMFILE = 0x9
            LC_PREPAGE = 0xa
            LC_DYSYMTAB = 0xb
            LC_LOAD_DYLIB = 0xc
            LC_ID_DYLIB = 0xd
            LC_LOAD_DYLINKER = 0xe
            LC_ID_DYLINKER = 0xf
            LC_PREBOUND_DYLIB = 0x10
            LC_ROUTINES = 0x11
            LC_SUB_FRAMEWORK = 0x12
            LC_SUB_UMBRELLA = 0x13
            LC_SUB_CLIENT = 0x14
            LC_SUB_LIBRARY = 0x15
            LC_TWOLEVEL_HINTS = 0x16
            LC_PREBIND_CKSUM = 0x17
            LC_LOAD_WEAK_DYLIB = (0x18 | LC_REQ_DYLD)
            LC_SEGMENT_64 = 0x19
            LC_ROUTINES_64 = 0x1a
            LC_UUID = 0x1b
            LC_RPATH = (0x1c | LC_REQ_DYLD)
            LC_CODE_SIGNATURE = 0x1d
            LC_SEGMENT_SPLIT_INFO = 0x1e
            LC_REEXPORT_DYLIB = (0x1f | LC_REQ_DYLD)
            LC_LAZY_LOAD_DYLIB = 0x20
            LC_ENCRYPTION_INFO = 0x21
            LC_DYLD_INFO = 0x22
            LC_DYLD_INFO_ONLY = (0x22 | LC_REQ_DYLD)
            LC_LOAD_UPWARD_DYLIB = (0x23 | LC_REQ_DYLD)
            LC_VERSION_MIN_MACOSX = 0x24
            LC_VERSION_MIN_IPHONEOS = 0x25
            LC_FUNCTION_STARTS = 0x26
            LC_DYLD_ENVIRONMENT = 0x27
            LC_MAIN = (0x28 | LC_REQ_DYLD)
            LC_DATA_IN_CODE = 0x29
            LC_SOURCE_VERSION = 0x2A
            LC_DYLIB_CODE_SIGN_DRS = 0x2B
            LC_ENCRYPTION_INFO_64 = 0x2C
            LC_LINKER_OPTION = 0x2D
            LC_LINKER_OPTIMIZATION_HINT = 0x2E
            LC_VERSION_MIN_TVOS = 0x2F
            LC_VERSION_MIN_WATCHOS = 0x30
            LC_NOTE = 0x31
            LC_BUILD_VERSION = 0x32
        end

        include LoadCommandConst

        class ReaderError < StandardError
        end

        class Reader
            attr_reader :fh, :startpos

            def self.parse(f)
                ob = new(f)
                ob.parse()
                return ob
            end

            def initialize(f)
                @fh = f
                @startpos = @fh.pos
            end

            def parse()
                @fh.pos = @startpos
            end

            def rewind()
                @fh.pos = @startpos
            end
        end

        class FatHeaderReader < Reader
            attr_reader :magic, :nfat_arch, :fat_arches

            def parse()
                super()
                @magic = @fh.read_uint32
                @nfat_arch = @fh.read_uint32
                @fat_arches = Array.new(@nfat_arch) { FatArchReader.parse(@fh) }

                unless MachO::is_fat_magic(@magic)
                    raise(ReaderError, "Unexpected magic value for FAT header: 0x%0.8x" % @magic)
                end
            end

            def machos()
                a = []
                each_macho {|mh| a << mh}
                return a
            end

            def each_macho()
                @fat_arches.each do |arch|
                    @fh.pos = @startpos + arch.offset
                    yield arch.macho_reader.parse(@fh)
                end
            end
        end

        class FatArchReader < Reader
            CPU_ARCH_ABI64 = 0x01000000

            attr_reader :cputype, :cpusubtype, :offset, :size, :align

            def parse()
                super()
                @cputype = @fh.read_uint32
                @cpusubtype = @fh.read_uint32
                @offset = @fh.read_uint32
                @size = @fh.read_uint32
                @align = @fh.read_uint32
            end

            def macho_reader
                if (@cputype & CPU_ARCH_ABI64) == 0
                    return MachHeaderReader
                else
                    return MachHeader64Reader
                end
            end
        end

        class CommonMachHeaderReader < Reader
            attr_reader :magic, :cputype, :cpusubtype, :filetype, :ncmds, :sizeofcmds, :flags

            attr_reader :load_commands

            def parse()
                super()
                @magic = @fh.read_uint32
                unless MachO::is_macho_magic(@magic)
                    raise(ReaderError, "Unrecognized magic value for mach header: 0x%0.8x" % @magic)
                end
                @cputype = @fh.read_uint32le
                @cpusubtype = @fh.read_uint32le
                @filetype = @fh.read_uint32le
                @ncmds = @fh.read_uint32le
                @sizeofcmds = @fh.read_uint32le
                @flags = @fh.read_uint32le
            end

            def all_load_commands_of_type(val)
                v = _normalize_lc_lookup_type(val)
                return [] if v.nil?
                load_commands.select{|x| x.cmd == v }
            end

            def find_load_command_of_type(val)
                v = _normalize_lc_lookup_type(val)
                return nil if v.nil?
                load_commands.find{|x| x.cmd == v }
            end

            def loaded_libraries()
                all_load_commands_of_type(:LC_LOAD_DYLIB).map {|lc| lc.dylib_name }
            end

            def rpaths()
                all_load_commands_of_type(:LC_RPATH).map{|lc| lc.rpath}.uniq
            end

            def read_at(offset, size)
                @fh.pos = @startpos + offset
                return @fh.read(size)
            end

            def codesignature_data()
                lc = find_load_command_of_type(:LC_CODE_SIGNATURE)
                return nil if lc.nil?
                read_at(lc.dataoff, lc.datasize)
            end

            def codesignature()
                cs = codesignature_data
                return nil if cs.nil?
                return AppleCodeSignature::parse(cs)
            end

            def is_32?()
                return (@magic == MACHO_MAGIC32)
            end

            def is_64?()
                return (@magic == MACHO_MAGIC64)
            end

            def encryption_info
                ectyp = (is_64?)? :LC_ENCRYPTION_INFO_64 : :LC_ENCRYPTION_INFO
                return find_load_command_of_type(ectyp)
            end

            def is_encrypted?
                ec = encryption_info
                return (ec and ec.cryptid != 0)
            end

            def segment_load_commands()
                segtyp = (is_64?)? :LC_SEGMENT_64 : :LC_SEGMENT
                return all_load_commands_of_type(segtyp)
            end

            private
            # called privately by subclasses after parse()
            def _parse_load_commands()
                @load_commands = Array.new(@ncmds) do
                    cmd = @fh.read_uint32le
                    @fh.pos -= 4
                    klass = MachO.reader_for_lc(cmd)
                    klass.parse(@fh)
                end
            end

            def _normalize_lc_lookup_type(val)
                if val.is_a?(Integer)
                    return val
                elsif val.is_a?(Symbol)
                    return MachO::lcmap[val]
                elsif val.is_a?(String)
                    return MachO::lcmap[val.to_sym]
                else
                    raise(ArgumentError, "Invalid load command lookup type: #{typ.class}")
                end
            end
        end

        class MachHeaderReader < CommonMachHeaderReader
            def parse()
                super()
                unless MachO::is_macho32_magic(@magic)
                    raise(ReaderError, "Unexpected magic value for Mach header: 0x%0.8x" % @magic)
                end
                _parse_load_commands()
            end
        end

        class MachHeader64Reader < CommonMachHeaderReader
            attr_reader :_reserved
            def parse()
                super()
                @_reserved = @fh.read_uint32le
                unless MachO::is_macho64_magic(@magic)
                    raise(ReaderError, "Unexpected magic value for Mach 64 header: 0x%0.8x" % @magic)
                end
                _parse_load_commands()
            end
        end

        class CommonLCReader < Reader
            attr_reader :cmd, :cmdsize
            def parse()
                super()
                @cmd = @fh.read_uint32le
                @cmdsize = @fh.read_uint32le
                if @cmdsize < 8
                    raise(ReaderError, "Load command size too small (#{@cmdsize} bytes) at offset #{@fh.pos - 4}")
                end
            end

            def resolve_type()
                MachO::resolve_lc(@cmd)
            end
        end

        class UndefinedLCReader < CommonLCReader
            attr_reader :cmd_data
            def parse()
                super()
                @cmd_data = StringStream.new(@fh.strictread(@cmdsize - 8))
            end
        end

        class CommonSegmentReader < CommonLCReader
            attr_reader :segname, :vmaddr, :vmsize, :fileoff, :filesize, :maxprot, :initprot, :nsects, :flags

            attr_reader :sections

            def parse()
                super()
                @segname = @fh.strictread(16)
            end

            def segment_name()
                @segname.unpack("Z16").first
            end
        end

        class CommonSectionReader < Reader
            attr_reader :sectname, :segname, :addr, :size, :offset, :align, :reloff, :nreloc, :flags, :_reserved1, :_reserved2
            def parse()
                super()
                @sectname = @fh.strictread(16)
                @segname = @fh.strictread(16)
            end

            def segment_name()
                @segname.unpack("Z16").first
            end

            def section_name()
                @sectname.unpack("Z16").first
            end
        end

        class SectionReader < CommonSectionReader
            def parse()
                super()
                @addr = @fh.read_uint32le
                @size = @fh.read_uint32le
                @offset = @fh.read_uint32le
                @align = @fh.read_uint32le
                @reloff = @fh.read_uint32le
                @nreloc = @fh.read_uint32le
                @flags = @fh.read_uint32le
                @_reserved1 = @fh.read_uint32le
                @_reserved2 = @fh.read_uint32le
            end
        end

        class Section64Reader < CommonSectionReader
            attr_reader :_reserved3
            def parse()
                super()
                @addr = @fh.read_uint64le
                @size = @fh.read_uint64le
                @offset = @fh.read_uint32le
                @align = @fh.read_uint32le
                @reloff = @fh.read_uint32le
                @nreloc = @fh.read_uint32le
                @flags = @fh.read_uint32le
                @_reserved1 = @fh.read_uint32le
                @_reserved2 = @fh.read_uint32le
                @_reserved3 = @fh.read_uint32le
            end
        end

        class LC_SEGMENT_Reader < CommonSegmentReader
            def parse()
                super()
                @vmaddr = @fh.read_uint32le
                @vmsize = @fh.read_uint32le
                @fileoff = @fh.read_uint32le
                @filesize = @fh.read_uint32le
                @maxprot = @fh.read_uint32le
                @initprot = @fh.read_uint32le
                @nsects = @fh.read_uint32le
                @flags = @fh.read_uint32le

                @sections = Array.new(@nsects) { SectionReader.parse(@fh) }
            end
        end

        class LC_SEGMENT_64_Reader < CommonSegmentReader
            def parse()
                super()
                @vmaddr = @fh.read_uint64le
                @vmsize = @fh.read_uint64le
                @fileoff = @fh.read_uint64le
                @filesize = @fh.read_uint64le
                @maxprot = @fh.read_uint32le
                @initprot = @fh.read_uint32le
                @nsects = @fh.read_uint32le
                @flags = @fh.read_uint32le

                @sections = Array.new(@nsects) { Section64Reader.parse(@fh) }
            end
        end

        class CommonLinkeditDataCommandReader < CommonLCReader
            attr_reader :dataoff, :datasize

            def parse()
                super()
                @dataoff = @fh.read_uint32le
                @datasize = @fh.read_uint32le
            end
        end

        class LC_CODE_SIGNATURE_Reader < CommonLinkeditDataCommandReader
        end

        class LC_SEGMENT_SPLIT_INFO_Reader < CommonLinkeditDataCommandReader
        end

        class LC_FUNCTION_STARTS_Reader < CommonLinkeditDataCommandReader
        end

        class LC_DATA_IN_CODE_Reader < CommonLinkeditDataCommandReader
        end

        class LC_DYLIB_CODE_SIGN_DRS_Reader < CommonLinkeditDataCommandReader
        end

        class LC_LINKER_OPTIMIZATION_HINT_Reader < CommonLinkeditDataCommandReader
        end

        class CommonEncryptionInfoReader < CommonLCReader
            attr_reader :cryptoff, :cryptsize, :cryptid

            def parse()
                super()
                @cryptoff = @fh.read_uint32le
                @cryptsize = @fh.read_uint32le
                @cryptid = @fh.read_uint32le
            end
        end

        class LC_ENCRYPTION_INFO_Reader < CommonEncryptionInfoReader
        end

        class LC_ENCRYPTION_INFO_64_Reader < CommonEncryptionInfoReader
            attr_reader :_pad

            def parse()
                super()
                @_pad = @fh.read_uint32le
            end
        end

        class DylibStructReader < Reader
            attr_reader :offset, :timestamp, :current_version, :compatibility_version

            def parse()
                super()
                @offset = @fh.read_uint32le
                @timestamp = @fh.read_uint32le
                @current_version = @fh.read_uint32le
                @compatibility_version = @fh.read_uint32le
            end
        end

        class CommonDylibCommandReader < CommonLCReader
            attr_reader :dylib_struct, :dylib_name_data

            def parse()
                super()
                @dylib_struct = DylibStructReader.parse(@fh)
                @dylib_name_data = @fh.strictread(self.cmdsize - self.dylib_struct.offset)
            end

            def dylib_name()
                @dylib_name_data.unpack("Z*").first
            end
        end

        class LC_ID_DYLIB_Reader < CommonDylibCommandReader
        end

        class LC_LOAD_DYLIB_Reader < CommonDylibCommandReader
        end

        class LC_LOAD_WEAK_DYLIB_Reader < CommonDylibCommandReader
        end

        class LC_REEXPORT_DYLIB_Reader < CommonDylibCommandReader
        end

        class LC_RPATH_Reader < CommonLCReader
            attr_reader :offset, :rpath_data

            def parse()
                super()
                @offset = @fh.read_uint32le
                @rpath_data = @fh.strictread(@cmdsize - @offset)
            end

            def rpath()
                @rpath_data.unpack("Z*").first
            end
        end
    end
end
