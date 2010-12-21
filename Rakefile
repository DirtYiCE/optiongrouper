# -*- mode: ruby; coding: utf-8 -*-

require 'rubygems'
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "optiongrouper"
  gem.homepage = "http://github.com/DirtYiCE/optiongrouper"
  gem.license = "MIT"
  gem.summary = "Command line option parsing library"
  gem.description = "Command line option parsing library with some fancy features"
  gem.email = "DirtY.iCE.hu@gmail.com"
  gem.authors = ["Kővágó, Zoltán"]
  # Include your dependencies below. Runtime dependencies are required when using your gem,
  # and development dependencies are only needed for development (ie running rake tasks, tests, etc)
  #  gem.add_runtime_dependency 'jabber4r', '> 0.1'
  #  gem.add_development_dependency 'rspec', '> 1.2.3'
  gem.add_runtime_dependency "blockenspiel", "~> 0.4.0"
  gem.add_development_dependency "rspec", "~> 2.1.0"
  gem.add_development_dependency "yard", "~> 0.6.0"
  gem.add_development_dependency "jeweler", "~> 1.5.1"
  gem.add_development_dependency "rcov", ">= 0"
end
Jeweler::RubygemsDotOrgTasks.new

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
end

RSpec::Core::RakeTask.new(:rcov) do |spec|
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

task :default => :spec

require 'yard'
YARD::Rake::YardocTask.new
