# encoding: utf-8

require File.expand_path('../lib/kamishibai/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'kamishibai'
  s.version     = Kamishibai::VERSION
  s.description = "Remote manga reader. Read manga anywhere using a web browser."
  s.summary     = s.description
  s.authors     = ["Mac Ma"]
  s.email       = 'gitmac@etneko.info'
  s.homepage    = 'http://rubygems.org/gems/kamishibai'
  s.license     = 'BSD 3-clause'

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.rubyforge_project = 'kamishibai'

  s.add_dependency 'addressable', '>= 2.3.5'
  s.add_dependency 'thin',      '>= 1.6.0'
  s.add_dependency 'ffi',       '>= 1.9.0'
  s.add_dependency 'gd2-ffij',  '>= 0.1.1'
  s.add_dependency 'json',      '>= 1.7.7'
  s.add_dependency 'rubyzip',   '>= 1.0.0'
  s.add_dependency 'sinatra',   '>= 1.4.4'
  
  s.require_paths = ['lib']
  s.files = `git ls-files`.split($\)
  s.executables = s.files.grep(%r{^bin/}).map { |f| File.basename(f) }
end