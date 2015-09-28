require 'spec_helper'

RSpec.describe StraightServer::Bip70::PaymentRequest do

  let(:gateway) { StraightServer::GatewayOnConfig.find_by_id(1) }
  let(:order) { create(:order, gateway_id: gateway.id) }

  it 'create payment request without CA certificates' do
    serialized_payment_request = StraightServer::Bip70::PaymentRequest.new(order: order).to_s
    payment_request = Payments::PaymentRequest.parse(serialized_payment_request)

    expect(payment_request.payment_details_version).to eq(1)
    expect(payment_request.pki_type).to eq('none')
    expect(payment_request.pki_data).to eq('')

    serialized_payment_details = payment_request.serialized_payment_details
    payment_details = Payments::PaymentDetails.parse(serialized_payment_details)

    expect(payment_details.network).to eq('test')
    expect(payment_details.memo).to eq('Payment request for GearPoweredMerchant')
    expect(payment_details.payment_url).to eq('')
    expect(payment_details.merchant_data).to eq('')
    expect(payment_details.expires - payment_details.time).to eq(gateway.orders_expiration_period)
    expect(payment_details.outputs.size).to eq(1)

    output = payment_details.outputs.first
    expect(output.amount).to eq(order.amount)
    expect(output.script).to eq(order.address)
  end

  it 'create payment request for mainnet' do
    gateway = StraightServer::GatewayOnConfig.find_by_id(2)
    order = create(:order, gateway_id: gateway.id)

    serialized_payment_request = StraightServer::Bip70::PaymentRequest.new(order: order).to_s
    payment_request = Payments::PaymentRequest.parse(serialized_payment_request)
    serialized_payment_details = payment_request.serialized_payment_details
    payment_details = Payments::PaymentDetails.parse(serialized_payment_details)

    expect(payment_details.network).to eq('main')
  end

  it 'create payment request with CA certificates' do
    certificates =
      "-----BEGIN CERTIFICATE-----\n" +
      "MIIDOTCCAiGgAwIBAgIBAjANBgkqhkiG9w0BAQsFADBCMRMwEQYKCZImiZPyLGQB\n" +
      "GRYDb3JnMRkwFwYKCZImiZPyLGQBGRYJcnVieS1sYW5nMRAwDgYDVQQDDAdSdWJ5\n" +
      "IENBMB4XDTE1MDkyNTExNDQyNloXDTE2MDkyNDExNDQyNlowSzETMBEGCgmSJomT\n" +
      "8ixkARkWA29yZzEZMBcGCgmSJomT8ixkARkWCXJ1YnktbGFuZzEZMBcGA1UEAwwQ\n" +
      "UnVieSBjZXJ0aWZpY2F0ZTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB\n" +
      "AN32fCnftGJ2qJcu8096uhnmrtaRM0Gvo0JNowzFyTQo9EqebJAbTKRRzu1fvHfR\n" +
      "D9MDsDnGgn/PdHLdGPzB/fEyvGi89Fy1sQgYIWItiw2ilNHUYEEPmumCMSxMQ1MT\n" +
      "wfMorqMNDWvpeM59L5KypZM1XmA5lS+79dfejp5ZlDbcjTySRPT1b67/GlgxEDKO\n" +
      "N9bASDifr/t+35Wr5UCA6R7VfpmVlhBJvNg38GM70jKtc+QgKD2oz+ScxMhP+wkG\n" +
      "/pleW+vyKYuXI/i3SkpXKm2C+wDW2kC2XiWOpw6gpfxk3QtWOhCE1d7VwXOtt/al\n" +
      "NyLejj1lQ3VAdnuUC0k9T/sCAwEAAaMxMC8wDgYDVR0PAQH/BAQDAgeAMB0GA1Ud\n" +
      "DgQWBBQ/gmtxvlHmMt1bVs4dyB+//OWkaTANBgkqhkiG9w0BAQsFAAOCAQEAs8A3\n" +
      "oqAeVSbusuBVDyPXePKh5NBfyh8yMw91ksB08go7AoSFbEgcRAs4RKkurDpPbZgq\n" +
      "XPB51X1dneJBURjKcrn2K947scOmP5U/GiP/0qK/8w7rA+5C2cxGAKtTx4rFrjMj\n" +
      "6jW/7mMfs6xYnN3RgcQO/HOVnEnTD4lSfJS/1QHTSwLTSBMty0qfWEewW9m70xOB\n" +
      "W8eMQUpaciCVF8qdRaph5rvtM7zs/eubi+PqNId0A+0/AOmLAwAy1zXam+O205gQ\n" +
      "GgaG7rtmEOqYZ89ZRYxAUzMHWoOCL0WOeOvmBQqsobhayIp8DUyiJTStGgBgy7IB\n" +
      "3TcyWu9NDAM2t71PSA==\n"                                             +
      "-----END CERTIFICATE-----\n"                                        +
      "-----BEGIN CERTIFICATE-----\n"                                      +
      "MIIDYjCCAkqgAwIBAgIBATANBgkqhkiG9w0BAQsFADBCMRMwEQYKCZImiZPyLGQB\n" +
      "GRYDb3JnMRkwFwYKCZImiZPyLGQBGRYJcnVieS1sYW5nMRAwDgYDVQQDDAdSdWJ5\n" +
      "IENBMB4XDTE1MDkyNTExNDQyNloXDTE3MDkyNDExNDQyNlowQjETMBEGCgmSJomT\n" +
      "8ixkARkWA29yZzEZMBcGCgmSJomT8ixkARkWCXJ1YnktbGFuZzEQMA4GA1UEAwwH\n" +
      "UnVieSBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAM5RMMU0imfB\n" +
      "PgnZHdroPjgg8/n0NaVgrGYC6+byjztboISmr9Vn8cGSMXeOaTV99GOm6eHmjYeO\n" +
      "0mUfNayeT4pRqvxfAcdrZGEjI3yIpxQOnSMMLtZxPbtAGbtlA6plXo96EJQGZQ+f\n" +
      "iPzLxfk/2VO0g04Ps5+neNeYHvQNj/uTjoiKqvPHHoSQxkkRgWpasrbi9W6Aev6q\n" +
      "55QblWY6+gkKY+ptYduvXpDsJpg56lynNmEXPCbIHwy6idhJJ2q+LlIp48vbltxM\n" +
      "pBdd36vjFDNh0zEAEYBfYgsZxxn3LslVX7IGj+y8/+aPDg9Lm89YIt028uQfTMPU\n" +
      "jNJc3HMSCZ8CAwEAAaNjMGEwDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMC\n" +
      "AQYwHQYDVR0OBBYEFD8QYdZYeJS4udohWZ0PcvV2qYm9MB8GA1UdIwQYMBaAFD8Q\n" +
      "YdZYeJS4udohWZ0PcvV2qYm9MA0GCSqGSIb3DQEBCwUAA4IBAQBK8UnX+0igB/R2\n" +
      "vWbOoauK7WR6X2akdmtA6pR/whW9fhOtw5WLvCKGEq1DW6USoi3qw35Wl0k2B1t0\n" +
      "FvZI21DW7Wbery7WOMDcc5uqLyvXmYbrEtVhcf0lQ0C/iZkKyv9KVOCSMwb8Aj88\n" +
      "/uWlX+8LofCnZ4YcX+VBn/crErwjf6PZtT84bZJH2u8m6fwqPKjmtIVjsiQ52Gdv\n" +
      "XjycrP4UnM/Q6ROFDD0qw3/W3QphelMExZWgq07YJ33ZCmmqUvTdC8ADLNZTYqJI\n" +
      "DH0X3eswZZtKJl1RMe9S5UPQPNcIa2zIutl0QBg+8RmjLbISJhkhRqZNsI7nSKhm\n" +
      "ARKdTqgx\n"                                                         +
      "-----END CERTIFICATE-----\n"

    ssl_certificate_path = '/tmp/.ca.crt'
    File.open(ssl_certificate_path, 'w') do |f|
      f.puts(certificates)
    end

    StraightServer::Config.ssl_certificate_path = ssl_certificate_path

    serialized_payment_request = StraightServer::Bip70::PaymentRequest.new(order: order).to_s
    payment_request = Payments::PaymentRequest.parse(serialized_payment_request)

    expect(payment_request.payment_details_version).to eq(1)
    expect(payment_request.pki_type).to eq('x509+sha256')

    x509_certificates = Payments::X509Certificates.parse(payment_request.pki_data)
    expect(x509_certificates.certificate).to be_truthy

    serialized_payment_details = payment_request.serialized_payment_details
    payment_details = Payments::PaymentDetails.parse(serialized_payment_details)

    expect(payment_details.network).to eq('test')
    expect(payment_details.memo).to eq('Payment request for GearPoweredMerchant')
    expect(payment_details.payment_url).to eq('')
    expect(payment_details.merchant_data).to eq('')
    expect(payment_details.expires - payment_details.time).to eq(gateway.orders_expiration_period)
    expect(payment_details.outputs.size).to eq(1)

    output = payment_details.outputs.first
    expect(output.amount).to eq(order.amount)
    expect(output.script).to eq(order.address)

    StraightServer::Config.ssl_certificate_path = nil
    File.delete(ssl_certificate_path)
  end

  it "return 'no private key was found' error" do
    private_key_path = StraightServer::Config.private_key_path
    StraightServer::Config.private_key_path = nil

    create_payment_request = -> { StraightServer::Bip70::PaymentRequest.new(order: order) }
    expect(create_payment_request).to raise_exception(StraightServer::Bip70::PaymentRequestError)

    StraightServer::Config.private_key_path = private_key_path
  end

end
