# frozen_string_literal: true

source 'https://rubygems.org'

# Allow the rails version to come from an ENV setting
# so Travis can test multiple versions.
# See http://www.schneems.com/post/50991826838/testing-against-multiple-rails-versions/
rails_version = ENV['RAILS_VERSION'] || '5.1.2'

gem 'rails', rails_version

case rails_version.split('.').first
when '3'
  gem 'strong_parameters'
when '4', '5'
  gem 'responders'
end

gem 'sqlite3'

gem 'rswag-api', path: './rswag-api'
gem 'rswag-specs', path: './rswag-specs'
gem 'rswag-ui', path: './rswag-ui'

# To use debugger
# gem 'debugger'

group :test do
  gem 'capybara'
  gem 'capybara-webkit'
  gem 'generator_spec'
  gem 'rspec-rails'
  gem 'test-unit'
end

group :assets do
  gem 'therubyracer'
  gem 'uglifier'
end
