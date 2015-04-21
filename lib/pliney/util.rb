require 'cfpropertylist'
require 'pathname'
require 'openssl'

module Pliney
    def self.parse_plist(rawdat)
        plist = CFPropertyList::List.new(data: rawdat)
        return CFPropertyList.native_types(plist.value)
    end
end
