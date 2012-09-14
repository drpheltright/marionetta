require File.dirname(__FILE__)+'/lib/marionetta'

Gem::Specification.new do |s|
  s.name        = "marionetta"
  s.version     = Marionetta::VERSION
  s.authors     = ["Luke Morton"]
  s.email       = ["lukemorton.dev@gmail.com"]
  s.summary     = Marionetta::DESCRIPTION
  s.description = Marionetta::DESCRIPTION

  s.files       = `git ls-files`.split("\n")
  s.test_files  = `git ls-files -- spec/*`.split("\n")
  s.executables = `git ls-files -- bin/*`.split("\n").map {|f| File.basename(f)}

  s.require_paths = ["lib"]

  s.add_dependency('rake-remote_task')

  s.add_development_dependency('rake')
  s.add_development_dependency('rspec')
end