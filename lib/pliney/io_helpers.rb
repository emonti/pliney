require 'stringio'

module Pliney
    module IOHelpers
        class StrictReadError < StandardError
        end

        def strictread(nbytes)
            _pos = self.pos
            res = read(nbytes)
            if res.nil?
                raise(StrictReadError, "read returned nil for read(#{nbytes}) at offset #{_pos}")
            end
            if res.bytesize != nbytes
                raise(StrictReadError, "read returned only #{res.size} bytes for read(#{nbytes}) at offset #{_pos}")
            end
            return res
        end

        def read_uint8
            getbyte
        end

        def read_uint16be
            strictread(2).unpack("n").first
        end

        def read_uint32be
            strictread(4).unpack("N").first
        end

        def read_uint64be
            v = strictread(8).unpack("NN")
            (v[0] << 32) | v[1]
        end

        alias read_uint16 read_uint16be
        alias read_uint32 read_uint32be
        alias read_uint64 read_uint64be

        def read_uint16le
            strictread(2).unpack("v").first
        end

        def read_uint32le
            strictread(4).unpack("V").first
        end

        def read_uint64le
            v = strictread(8).unpack("VV")
            (v[1] << 32) | v[0]
        end
    end
end

class StringStream < StringIO
    include Pliney::IOHelpers
end

class IO
    include Pliney::IOHelpers
end


