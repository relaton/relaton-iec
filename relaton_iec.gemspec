lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "relaton_iec/version"

Gem::Specification.new do |spec|
  spec.name          = "relaton-iec"
  spec.version       = RelatonIec::VERSION
  spec.authors       = ["Ribose Inc."]
  spec.email         = ["open.source@ribose.com"]

  spec.summary       = "RelatonIec: retrieve IEC Standards for bibliographic " \
                       "use using the IecBibliographicItem model"
  spec.description   = "RelatonIec: retrieve IEC Standards for bibliographic " \
                       "use using the IecBibliographicItem model"
  spec.homepage      = "https://github.com/metanorma/relaton-iec"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.required_ruby_version = Gem::Requirement.new(">= 2.5.0")

  spec.add_development_dependency "equivalent-xml", "~> 0.6"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"

  spec.add_dependency "addressable"
  spec.add_dependency "relaton-index", "~> 0.2.0"
  spec.add_dependency "relaton-iso-bib", "~> 1.14.0"
  spec.add_dependency "rubyzip"
end
