# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pliney/version'

Gem::Specification.new do |spec|
  spec.name          = "pliney"
  spec.version       = Pliney::VERSION
  spec.authors       = ["Eric Monti"]
  spec.email         = ["esmonti@gmail.com"]
  spec.summary       = %q{Pliney is for working with Apple IPA files}
  spec.description   = %q{Includes various helpers and interfaces for working with IPA files, mobileprovisioning, and other formats related Apple iOS apps.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "rubyzip"
  spec.add_dependency "CFPropertyList"

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "coveralls"
end
