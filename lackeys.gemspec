# frozen_string_literal: true

# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'lackeys/version'

Gem::Specification.new do |spec|
  spec.name          = 'lackeys'
  spec.version       = Lackeys::VERSION
  spec.authors       = ['Adrian Joseph Tumusok']
  spec.email         = ['adrian@egissys.com']
  spec.summary       = 'Allows a service modules connect to a class painlessly'
  spec.description   = <<-EOS
    Lackeys is a pubsub implementation that lets users automatically hook into
    existing classes.
  EOS
  spec.homepage      = ''
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bini/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'activemodel'
end
