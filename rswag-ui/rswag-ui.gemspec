# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'rswag-ui'
  s.version     = ENV['TRAVIS_TAG'] || '0.0.0'
  s.authors     = ['Richie Morris',
                   'Xavier Mortelette']
  s.email       = ['domaindrivendev@gmail.com',
                   'xavier.mortelette@pragmitil.com']
  s.homepage    = 'https://github.com/reivaxm/rswag'
  s.summary     = 'A Rails Engine that includes swagger-ui and powers it ' \
                  'from configured Swagger endpoints'
  s.description = 'Expose beautiful API documentation, that\'s powered by ' \
                  'Swagger JSON endpoints, including a UI to explore and ' \
                  'test operations'
  s.license     = 'MIT'

  s.files = Dir['{app,config,lib,vendor}/**/*'] + ['MIT-LICENSE', 'Rakefile']

  s.add_dependency 'actionpack', '>=3.1', '< 6.0'
  s.add_dependency 'coffee-rails'
  s.add_dependency 'railties', '>= 3.1', '< 6.0'
  s.add_dependency 'sass-rails'
  s.add_dependency 'therubyracer'
  s.add_dependency 'uglifier'
end
