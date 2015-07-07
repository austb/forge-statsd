lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'puppet_forge_statsd/version'

Gem::Specification.new do |spec|
    spec.name          = "puppet_forge_statsd"
    spec.version       = ForgeStatsD::VERSION 
    spec.authors       = ["Puppet Labs"]
    spec.email         = ["austin.blatt@puppetlabs.com"]
    spec.summary       = "Adds additional functionality that allows for the accumulation of times during a single request."
    spec.homepage      = "https://github.com/puppetlabs/forge-statsd"
    spec.license       = "Apache-2.0"

    spec.files         = `git ls-files -z`.split("\x0")
    spec.test_files    = spec.files.grep(/^(spec)\//)
    spec.require_paths = ["lib"]

    spec.required_ruby_version = '>= 1.9.3'

    spec.add_runtime_dependency "statsd-instrument", "~> 2.0.7"

    spec.add_development_dependency "bundler", "~> 1.6"
    spec.add_development_dependency "rake"
    spec.add_development_dependency "rspec"
end

