require 'spec_helper'

RSpec.describe StraightServer::Bip70::PaymentRequest do

  let(:gateway) { StraightServer::GatewayOnConfig.find_by_id(1) }
  let(:order) { create(:order, keychain_id: 1, gateway_id: gateway.id, amount: 1000) }

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
    script_string = BTC::Script.new(data: output.script).to_s

    expect(output.amount).to eq(1000)
    expect(script_string).to eq('OP_DUP OP_HASH160 d58f44fcb88037edcf9add05e045c0eec493c035 OP_EQUALVERIFY OP_CHECKSIG')
  end

  it "return 'no private key was found' error" do
    private_key_path = StraightServer::Config.private_key_path
    StraightServer::Config.private_key_path = nil

    create_payment_request = -> { StraightServer::Bip70::PaymentRequest.new(order: order) }
    expect(create_payment_request).to raise_exception(StraightServer::Bip70::PaymentRequestError)

    StraightServer::Config.private_key_path = private_key_path
  end

  it 'create payment request without CA certificates' do
    ssl_certificate_path = StraightServer::Config.ssl_certificate_path
    StraightServer::Config.ssl_certificate_path = nil

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
    script_string = BTC::Script.new(data: output.script).to_s

    expect(output.amount).to eq(1000)
    expect(script_string).to eq('OP_DUP OP_HASH160 d58f44fcb88037edcf9add05e045c0eec493c035 OP_EQUALVERIFY OP_CHECKSIG')

    StraightServer::Config.ssl_certificate_path = ssl_certificate_path
  end

end
