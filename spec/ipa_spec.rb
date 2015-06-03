require_relative 'spec_helper'
require 'pliney'

describe Pliney::IPA do
    before :each do
        @ipa = Pliney::IPA.from_path(sample_file("pliney-test.ipa"))
    end

    after :each do
        @ipa.close
    end

    it "loads an ipa" do
        @ipa.should be_a Pliney::IPA
    end

    it "gets the bundle identifier" do
        @ipa.bundle_identifier.should == "computer.versus.pliney-test"
    end

    it "gets the executable path" do
        @ipa.executable_path.should == Pathname("Payload/pliney-test.app/pliney-test")
    end

    it "reads the executable magic value" do
        @ipa.read_path(@ipa.executable_path, 4).unpack("N").first.should == 0xcafebabe
    end

    it "reads the info_plist" do
        @ipa.info_plist.should be_a Hash
        @ipa.info_plist["CFBundleExecutable"].should == "pliney-test"
        @ipa.info_plist["CFBundleShortVersionString"].should == "1.0"
    end

    it "lists the ipa contents" do
        @ipa.ls.sort.should == %w[
            Payload/
            Payload/pliney-test.app/
            Payload/pliney-test.app/Base.lproj/
            Payload/pliney-test.app/Base.lproj/LaunchScreen.nib
            Payload/pliney-test.app/Base.lproj/Main.storyboardc/
            Payload/pliney-test.app/Base.lproj/Main.storyboardc/Info.plist
            Payload/pliney-test.app/Base.lproj/Main.storyboardc/UIViewController-vXZ-lx-hvc.nib
            Payload/pliney-test.app/Base.lproj/Main.storyboardc/vXZ-lx-hvc-view-kh9-bI-dsS.nib
            Payload/pliney-test.app/Info.plist
            Payload/pliney-test.app/PkgInfo
            Payload/pliney-test.app/_CodeSignature/
            Payload/pliney-test.app/_CodeSignature/CodeResources
            Payload/pliney-test.app/embedded.mobileprovision
            Payload/pliney-test.app/pliney-test
        ]
    end

    it "reads the provisioning profile" do
        @ipa.provisioning_profile.should be_a Pliney::ProvisioningProfile
        @ipa.provisioning_profile.name.should == "Pliney Test Profile"
        @ipa.provisioning_profile.team_identifier.should == ["UL736KYQR9"]
    end

    it "gets the bundle version" do
        @ipa.bundle_version.should == "1"
    end

    it "gets the bundle short version string" do
        @ipa.bundle_short_version.should == "1.0"
    end

    it "reads the executable object"

    it "reads the entitlements"

end

