# -*- encoding: utf-8 -*-
require File.expand_path('../lib/codify/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Ronald Ping Man Chan"]
  gem.email         = ["ronalchn@gmail.com"]
  gem.description   = %q{Transparently encodes text before saving to your database.}
  gem.summary       = %q{Automatically encodes any desired text attributes for saving to database, and unencodes when retrieving the field. Includes encoding for compression, encryption and error checking.}
  gem.homepage      = "https://github.com/ronalchn/codify"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "codify"
  gem.require_paths = ["lib"]
  gem.version       = Codify::VERSION

  # specify any dependencies here; for example:
  gem.add_development_dependency "rake"
  gem.add_development_dependency "rspec"
  gem.add_development_dependency "sqlite3"
  gem.add_development_dependency "database_cleaner"
  gem.add_development_dependency "debugger"
  gem.add_development_dependency "datamapper"

  gem.add_runtime_dependency "activerecord", '>= 3.0'
end
