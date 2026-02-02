lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "relaton/iec/version"

Gem::Specification.new do |spec|
  spec.name          = "relaton-iec"
  spec.version       = Relaton::Iec::VERSION
  spec.authors       = ["Ribose Inc."]
  spec.email         = ["open.source@ribose.com"]

  spec.summary       = "Relaton::Iec: retrieve IEC Standards for bibliographic " \
                       "use using the IecBibliographicItem model"
  spec.description   = "Relaton::Iec: retrieve IEC Standards for bibliographic " \
                       "use using the IecBibliographicItem model"
  spec.homepage      = "https://github.com/relaton/relaton-iec"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.required_ruby_version = Gem::Requirement.new(">= 3.1.0")

  spec.add_dependency "addressable"
  spec.add_dependency "base64"
  spec.add_dependency "relaton-core", "~> 0.0.7"
  spec.add_dependency "relaton-index", "~> 0.2.0"
  spec.add_dependency "relaton-iso", "~> 2.0.0-alpha.1"
  spec.add_dependency "rubyzip"
end
