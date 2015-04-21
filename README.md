# Pliney
[![Gem Version](https://badge.fury.io/rb/pliney.svg)](https://badge.fury.io/rb/pliney)
[![Build Status](https://secure.travis-ci.org/emonti/pliney.svg)](https://travis-ci.org/emonti/pliney)
[![Code Climate](https://codeclimate.com/github/emonti/pliney.svg)](https://codeclimate.com/github/emonti/pliney)
[![Coverage Status](https://coveralls.io/repos/emonti/pliney/badge.svg?branch=master)](https://coveralls.io/r/emonti/pliney?branch=master)

Pliney is for working with Apple IPAs.

Includes various helpers and interfaces for working with IPA files,
mobileprovisioning, and other file formats related to Apple iOS apps.


## Installation

Add this line to your application's Gemfile:

    gem 'pliney'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install pliney


## Usage

    ipa = Pliney::IPA.from_path 'spec/samples/pliney-test.ipa'
    # => #<Pliney::IPA:0x...

    ipa.bundle_identifier
    # => "computer.versus.pliney-test"

    ipa.appdir
    # => #<Pathname:Payload/pliney-test.app/>

    ipa.executable_path
    # => #<Pathname:Payload/pliney-test.app/pliney-test>

    ipa.info_plist
    # => { "DTSDKName"=>"iphoneos8.2", "CFBundleName"=>"pliney-test", "DTXcode"=>"0620", ...

    ipa.read_path(ipa.executable_path)
    # => "\xCA\xFE\xBA\xBE\x00\x00\x00\...

    profile = ipa.provisioning_profile
    # => #<Pliney::ProvisioningProfile:0x0...

    profile.developer_certificates
    # => [#<OpenSSL::X509::Certificate:...
    
    profile.expiration_date
    # => 2016-04-20 14:18:13 -0700

    profile.expired?
    # => false

    profile.entitlements
    # => #<Pliney::EntitlementsMask:0x0000010330cc18 @ents={"keychain-access-groups"=>[...

    ipa.close


## TODOS

- macho parsing
- entitlements extraction/parsing/serialization
- ?
