require 'fileutils'
require 'hashie'
require_relative '../lib/straight-server'

# This tells initializer where to read the config file from
ENV['HOME'] = File.dirname(__FILE__)

StraightServer::Initializer.new.prepare

require_relative 'support/custom_matchers'

require "factory_girl"
require_relative "factories"

require 'webmock/rspec'

class StraightServer::Thread
  def self.new(label: nil, &block)
    block.call
    {label: label}
  end
end

RSpec.configure do |config|

  config.include FactoryGirl::Syntax::Methods

  config.before(:each) do |spec|
    StraightServer.db_connection[:orders].delete
    StraightServer.db_connection[:gateways].delete
    logger_mock = double("logger mock")
    [:debug, :info, :warn, :fatal, :unknown, :blank_lines].each do |e|
      allow(logger_mock).to receive(e)
    end

    allow(logger_mock).to receive(:watch_exceptions).and_yield

    StraightServer.logger = logger_mock
    StraightServer::GatewayOnConfig.class_variable_get(:@@gateways).each do |g|
      g.last_keychain_id = 0
      g.save
    end

    # Clear Gateway's order counters in Redis
    StraightServer.redis_connection.keys("#{StraightServer::Config.redis[:prefix]}*").each do |k|
      StraightServer.redis_connection.del k
    end

  end

  config.after(:all) do
    [*Dir["spec/.straight/*_last_keychain_id"]].each do |file|
      FileUtils.rm_f file
    end
  end

end
