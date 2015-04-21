
module Pliney
    class Entitlements
        def self.from_data(data)
            new(Pliney.parse_plist(data))
        end

        attr_reader :ents
        def initialize(ents)
            @ents = ents
        end
    end
end
