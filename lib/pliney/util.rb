require 'cfpropertylist'
require 'pathname'
require 'openssl'

module Pliney
    def self.parse_plist(rawdat)
        plist = CFPropertyList::List.new(data: rawdat)
        return CFPropertyList.native_types(plist.value)
    end

    def self.write_plist(data, outpath, format = CFPropertyList::List::FORMAT_XML)
        plist = CFPropertyList::List.new
        plist.value = CFPropertyList.guess(data)
        plist.save(outpath, format)
    end
end
