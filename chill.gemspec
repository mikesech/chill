# encoding: utf-8
$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require 'chill'

Gem::Specification.new do |s|
  s.name = 'chill'
  s.summary = 'Starts a subprocess that dies when its parent does.'
  s.description = 'Chill starts a subprocess that dies when its parent does.'
  s.homepage = 'http://github.com/mikesech/chill'
  s.version = Chill::VERSION
  s.licenses =  ['MIT']

  s.authors = [ 'Michael Sechooler' ]
  s.email = [ 'mikesech@gmail.com' ]

  s.require_paths = ['lib']
  s.files = %w( README.md LICENSE chill.gemspec )
  s.files += Dir.glob('lib/**/*')
end
