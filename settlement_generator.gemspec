Gem::Specification.new do |s|
  s.name        = 'settlement_generator'
  s.version     = '0.1.0'
  s.summary     = "Generate shops, trading posts, villages, towns and more"
  s.description = "A tool that randomly produces settlement content based on Spectacular Settlements by Nord Games"
  s.authors     = ["Egan Neuhengen"]
  s.email       = 'lightningworks@gmail.com'
  s.files       = ["bin/namegen", "bin/settlement", "config/*.yaml", "data/**/*.yaml", "lib/*.rb"]
  s.homepage    =
    'https://github.com/whitemage12380/settlement_generator'
  s.license       = 'GNU GPLv3'
end