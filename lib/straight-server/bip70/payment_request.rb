require_relative 'paymentrequest.pb'

module StraightServer

  module Bip70

    class PaymentRequestError < StandardError; end

    class PaymentRequest

      def initialize(order:)
        @order = order

        output   = create_output
        details  = create_payment_details(output)

        @payment_request = Payments::PaymentRequest.new
        @payment_request.payment_details_version    = 1
        @payment_request.serialized_payment_details = details.to_s

        @payment_request.pki_type, @payment_request.pki_data = create_pk_infrastructure

        @payment_request.signature = ''
        @payment_request.signature = create_signature(@payment_request.to_s)
      end

      def to_s
        @payment_request.to_s
      end

      private

        def create_output
          output = Payments::Output.new
          output.amount = @order.amount_to_pay
          output.script = BTC::Address.parse(@order.address).script.data
          output
        end

        def create_payment_details(output)
          payment_details = Payments::PaymentDetails.new
          payment_details.network = @order.gateway.test_mode ? 'test' : 'main'
          payment_details.time = @order.created_at.to_i
          payment_details.expires = @order.created_at.to_i + @order.gateway.orders_expiration_period
          payment_details.memo = 'Payment request for GearPoweredMerchant'
          payment_details.payment_url = ''
          payment_details.merchant_data = ''
          payment_details.outputs << output
          payment_details
        end

        def create_pk_infrastructure
          if Config.ssl_certificate_path
            pki_data = create_pki_data
            ['x509+sha256', pki_data.to_s]
          else
            ['none', '']
          end
        end

        def create_pki_data
          pki_data = Payments::X509Certificates.new

          certificates = File.read(Config.ssl_certificate_path)
          certificates.each_line("-----END CERTIFICATE-----\n") do |cert|
            pki_data.certificate << OpenSSL::X509::Certificate.new(cert).to_der
          end

          pki_data
        end

        def create_signature(data)
          if Config.private_key_path.nil?
            raise PaymentRequestError.new('No private key was found! Please provide it in config file')
          end

          key = File.read(Config.private_key_path)

          private_key = OpenSSL::PKey::RSA.new(key)
          private_key.sign(OpenSSL::Digest::SHA256.new, data)
        end

    end
  end
end
