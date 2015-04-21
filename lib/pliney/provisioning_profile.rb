require 'pliney/util'
require 'pliney/entitlements'
require 'openssl'

module Pliney
    class EntitlementsMask < Entitlements
    end

    class ProvisioningProfile
        def self.plist_from_asn1(rawdat)
            asn1 = OpenSSL::ASN1.decode(rawdat)
            plist_data = asn1.value[1].value[0].value[2].value[1].value[0].value
            return Pliney.parse_plist(plist_data)
        end

        def self.from_asn1(rawdat)
            new(plist_from_asn1(rawdat))
        end

        def self.from_file(path)
            from_asn1(File.binread(path))
        end

        attr_reader :plist

        def initialize(plist)
            raise ArgumentError.new("invalid plist") unless plist.is_a?(Hash)
            @plist = plist
        end

        def creation_date
            plist["CreationDate"]
        end

        def expiration_date
            plist["ExpirationDate"]
        end

        def expired?
            not (creation_date.to_i .. expiration_date.to_i).include?(Time.now.to_i)
        end

        def entitlements
            @ents ||= EntitlementsMask.new(plist["Entitlements"])
        end

        def developer_certificates
            @developer_certs ||= plist["DeveloperCertificates"].map{|cer| OpenSSL::X509::Certificate.new(cer)}
        end

        def appid_name
            plist["AppIDName"]
        end

        def appid_prefix
            plist["ApplicationIdentifierPrefix"]
        end

        def name
            plist["Name"]
        end

        def team_identifier
            plist["TeamIDentifier"]
        end

        def team_name
            plist["TeamName"]
        end

        def ttl
            plist["TimeToLive"]
        end

        def uuid
            plist["UUID"]
        end

        def version
            plist["Version"]
        end

        def provisioned_devices
            plist["ProvisionedDevices"]
        end
    end
end
