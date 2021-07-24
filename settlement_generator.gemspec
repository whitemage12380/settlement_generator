require 'rake'
Gem::Specification.new do |s|
  s.name        = 'settlement_generator'
  s.version     = '0.7.0'
  s.summary     = "Generate shops, trading posts, villages, towns and more"
  s.description = "A tool that randomly produces settlement content based on Spectacular Settlements by Nord Games"
  s.authors     = ["Egan Neuhengen"]
  s.email       = 'lightningworks@gmail.com'
  s.files       = FileList["bin/namegen", "bin/settlement", "config/*.yaml", "data/**/*.yaml", "lib/*.rb"].to_a
  s.homepage    =
    'https://github.com/whitemage12380/settlement_generator'
  s.license       = 'MPL-2.0'
end
