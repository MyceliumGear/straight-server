source 'https://rubygems.org' do
  if ENV['BUILD_ROOT'].to_s.empty?
    gem 'straight', '1.0.0' #, path: '../straight-engine'
  else
    gem 'straight', git: "#{ENV['BUILD_ROOT']}/straight/.git", ref: ENV['STRAIGHT_REF']
    gem 'pg'
    gem 'logstash-logger', github: 'dwbutler/logstash-logger', ref: '621ba20862424f3993c620fc4b1fb0bf819da9e1' # https://github.com/dwbutler/logstash-logger/pull/54
  end
  gem 'satoshi-unit', '>= 0.1.8'
  gem 'goliath'
  gem 'faye-websocket'
  gem 'socket.io-client-simple'
  gem 'sequel'
  gem 'logmaster', github: 'AlexanderPavlenko/logmaster'
  gem 'ruby-hmac'
  gem 'httparty'
  gem 'redis'
  gem 'btcruby', '1.1.1'
end

unless ENV['STRAIGHT_SERVER_IGNORE_ADDONS_GEMFILE'] # use this flag when building straight-server.gemspec
  addons_gemfile = ENV['STRAIGHT_SERVER_ADDONS_GEMFILE'] || File.join(ENV['STRAIGHT_SERVER_CONFIG_DIR'] || File.join(ENV['HOME'], '.straight'), 'AddonsGemfile')
  eval_gemfile addons_gemfile if File.exists?(addons_gemfile)
end

group :development do
  gem 'byebug'
  gem 'bundler', '~> 1.0'
  gem 'jeweler', '~> 2.0.1'
  gem 'github_api', '0.11.3'
end

group :test do
  gem 'timecop'
  gem 'rspec'
  gem 'factory_girl'
  gem 'sqlite3'
  gem 'hashie'
  gem 'webmock', require: false
end
