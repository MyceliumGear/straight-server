module StraightServer

  class StraightServerError < StandardError; end

  class SignatureValidator::SignatureValidatorError < StraightServerError; end
  class SignatureValidator::InvalidNonce            < SignatureValidator::SignatureValidatorError; end
  class SignatureValidator::InvalidSignature        < SignatureValidator::SignatureValidatorError; end

  class RoutingError < StraightServerError
    def initialize(method, path)
      super("#{method} #{path} Not found")
    end
  end

  module GatewayModule
    class GatewayInactive            < StraightServerError; end
    class CallbackUrlBadResponse     < StraightServerError; end

    class NoBlockchainAdapters < StraightServerError
      def message
        "No blockchain adapters were found! StraightServer cannot query the blockchain.\n" +
        "Check your ~/.straight/config.yml file and make sure valid blockchain adapters\n" +
        "are present."
      end
    end

    class NoWebsocketsForNewGateway < StraightServerError
      def message
        "You're trying to get access to websockets on a Gateway that hasn't been saved yet"
      end
    end

    class OrderCountersDisabled < StraightServerError
      def message
        "Please enable order counting in config file! You can do is using the following option:\n\n" +
        "  count_orders: true\n\n" +
        "and don't forget to provide Redis connection info by adding this to the config file as well:\n\n" +
        "  redis:\n" +
        "    host: localhost\n" +
        "    port: 6379\n" +
        "    db:   null\n"
      end
    end

    class NoPubkey < StraightServerError
      def message
        "No public key were found! Gateway can't work without it.\n" +
        "Please provide it in config file or DB."
      end
    end

    class NoTestPubkey < StraightServerError
      def message
        "No test public key were found! Gateway can't work in test mode without it.\n" +
        "Please provide it in config file or DB."
      end
    end

    class RecordNotFound < StraightServerError
      def message
        "Gateway not found"
      end
    end
  end

end
