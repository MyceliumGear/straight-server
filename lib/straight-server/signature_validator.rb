require 'goliath/constants'

module StraightServer
  class SignatureValidator
    include Goliath::Constants

    attr_reader :gateway, :env

    def initialize(gateway, env)
      @gateway = gateway
      @env     = env
    end

    def validate!
      raise InvalidSignature unless valid_signature?
      true
    end

    def valid_signature?
      actual = env["#{HTTP_PREFIX}X_SIGNATURE"]
      actual == signature ||
        actual == self.class.signature2(**signature_params)
    end

    def signature
      self.class.signature(**signature_params)
    end

    def signature_params
      {
        nonce:       env["#{HTTP_PREFIX}X_NONCE"],
        body:        env[RACK_INPUT].kind_of?(StringIO) ? env[RACK_INPUT].string : env[RACK_INPUT].to_s,
        method:      env[REQUEST_METHOD],
        request_uri: env[REQUEST_URI],
        secret:      gateway.secret,
      }
    end

    # Should mirror StraightServerKit.signature
    def self.signature(nonce:, body:, method:, request_uri:, secret:)
      sha512  = OpenSSL::Digest::SHA512.new
      request = "#{method.to_s.upcase}#{request_uri}#{sha512.digest("#{nonce}#{body}")}"
      Base64.strict_encode64 OpenSSL::HMAC.digest(sha512, secret.to_s, request)
    end

    # Some dumb libraries cannot convert into binary strings
    def self.signature2(nonce:, body:, method:, request_uri:, secret:)
      sha512  = OpenSSL::Digest::SHA512.new
      request = "#{method.to_s.upcase}#{request_uri}#{sha512.hexdigest("#{nonce}#{body}")}"
      OpenSSL::HMAC.hexdigest(sha512, secret.to_s, request)
    end
  end
end
