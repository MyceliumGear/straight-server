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
      actual = env["#{HTTP_PREFIX}X_SIGNATURE"].to_s.strip
      return false if actual.empty?
      actual == signature || actual == signature2 || superuser_signature?(actual)
    end

    def signature
      self.class.signature(**signature_params)
    end

    def signature2
      self.class.signature2(**signature_params)
    end

    def superuser_signature?(signature)
      return if StraightServer::Config[:superuser_public_key].to_s.empty?
      begin
        decoded = Base64.strict_decode64(signature)
      rescue
        return false
      end
      begin
        public_key = OpenSSL::PKey::RSA.new(StraightServer::Config[:superuser_public_key])
      rescue
        return
      end
      self.class.superuser_signature?(public_key: public_key, signature: decoded, **signature_params)
    rescue => ex
      StraightServer.logger.debug ex.message
      nil
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

    def self.superuser_signature?(public_key:, signature:, nonce:, body:, method:, request_uri:, **)
      sha512  = OpenSSL::Digest::SHA512.new
      request = "#{method.to_s.upcase}#{request_uri}#{sha512.digest("#{nonce}#{body}")}"
      public_key.verify(sha512, signature, request)
    end
  end
end
