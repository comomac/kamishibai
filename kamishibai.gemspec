# encoding: utf-8

require File.expand_path('../lib/kamishibai/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'kamishibai'
  s.version     = Kamishibai::VERSION
  s.summary     = "Manga web server"
  s.description = "Read your manga anywhere using a web browser"
  s.authors     = ["Mac Ma"]
  s.email       = 'gitmac@etneko.info'
  s.homepage    = 'http://rubygems.org/gems/kamishibai'
  s.license     = 'BSD-3-Clause'

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.rubyforge_project = 'kamishibai'

  s.add_dependency 'addressable', '= 2.3.5'
  s.add_dependency 'thin',        '= 1.8.2'
  s.add_dependency 'ffi',         '= 1.14.0'
  s.add_dependency 'gd2-ffij',    '= 0.4.0'
  s.add_dependency 'rubyzip',     '= 1.0.0'
  s.add_dependency 'sinatra',     '= 1.4.4'
  s.add_dependency 'sinatra-contrib',  '= 1.4.2'
  s.add_dependency 'memory_profiler',  '= 1.0.2'
  
  s.add_development_dependency 'bundler', '= 2.1.4'

  s.require_paths = ['lib']
  s.files = `git ls-files`.split($\)
  s.executables = s.files.grep(%r{^bin/}).map { |f| File.basename(f) }
end
