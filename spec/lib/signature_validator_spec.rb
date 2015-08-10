require 'spec_helper'

RSpec.describe StraightServer::SignatureValidator do

  it 'calculates signature' do
    expect(described_class.signature(nonce: '123', body: '', method: 'GET', request_uri: '/somewhere', secret: 'gateway_secret')).to eq 'ZSWEKzuWy6QWCc05I+t4QYQhUtkeogkW7rCwieQvy/56Y+bVwxGGKB3yNQg1XL2LmtuNNwv2SXUxjlFEP7+0+A=='
    expect(described_class.signature(nonce: '123', body: '', method: 'GET', request_uri: '/somewhere', secret: 'gateway-secret')).to eq 'nYLq7IXlgw5FAsXGc0+JoXmfHBEwl7zwVQhsix+FraIIFsPeGYnQ/22wkjPAwwyu0GoYEbM6gmN+sxEzciNkFg=='
    expect(described_class.signature(nonce: '12345', body: 'text' * 10000, method: 'POST', request_uri: '/somewhere', secret: 'gateway_secret')).to eq 'F0GsyqPkxDgmqdTomIGVIRQ/ik2GiZtXy1GVNx0j+UDUL8VS496HsbcOlyUocKUM0fU96KkjhrpUh0LC29AXyQ=='
  end

  it 'validates signature' do
    @validator = described_class.new(
      Struct.new(:secret).new('abc'),
      {
        'HTTP_X_NONCE'   => '1',
        'rack.input'     => 'request body',
        'REQUEST_METHOD' => 'POST',
        'REQUEST_URI'    => '/gateway/123/orders',
      }
    )
    expect(@validator.env['HTTP_X_SIGNATURE'] = @validator.signature).to eq '1EtQNASecMF85tyag+pSSdF2yxLfy3xCddM2ZGA86M8OTxleEixBnbOeMEBp37Ke5+7jWQm+Gpx95y6MZiW6wQ=='
    expect(@validator.valid_signature?).to eq true

    # without signature
    @validator.env['HTTP_X_SIGNATURE'] = ''
    expect(@validator.valid_signature?).to eq false

    # hexdigest signature
    expect(@validator.env['HTTP_X_SIGNATURE'] = @validator.class.signature2(**@validator.signature_params)).to eq '1d1349701164eb32224d15967649a2e943c0bfa0e7417c99cc387ca9b234d9f4c39f70185a4ac581e70dd03dc9ac23eb5a47de0ff341c169f0e7a4d6a2b8931b'
    expect(@validator.valid_signature?).to eq true
  end

  # https://jsfiddle.net/x37prst5/
  it 'accepts CryptoJS signature' do
    @validator = described_class.new(
      Struct.new(:secret).new('gateway_secret'),
      {
        'HTTP_X_NONCE'   => '123',
        'rack.input'     => '',
        'REQUEST_METHOD' => 'GET',
        'REQUEST_URI'    => '/somewhere',
      }
    )
    @validator.env['HTTP_X_SIGNATURE'] = 'c7d0f11725bdb7d7183ab117317684fcf76b7d8365fa9971f5679d6c5412f518d1b891a7a22339eeafde1a8f28a28a3f08a701a9787ec505f4a143dd02ae3232'
    expect(@validator.valid_signature?).to eq true
  end

  it 'validates nonce' do
    @validator = described_class.new(
      Struct.new(:id).new(1),
      {'HTTP_X_NONCE' => '100500'}
    )
    expect(@validator.valid_nonce?).to eq true
    expect(@validator.valid_nonce?).to eq false
    @validator.env['HTTP_X_NONCE'] = '100499'
    expect(@validator.valid_nonce?).to eq false
    @validator.env['HTTP_X_NONCE'] = '100501'
    expect(@validator.valid_nonce?).to eq true
    expect(@validator.valid_nonce?).to eq false
  end

  it 'validates nonce in a thread-safe way' do
    # TODO: test on real concurrency (JRuby?)
    @validator    = described_class.new(
      Struct.new(:id).new(2),
      {'HTTP_X_NONCE' => '100500'}
    )
    thread_number = 100
    @threads      = thread_number.times.map do |i|
      Thread.new do
        sleep (thread_number - i) / 10000.0
        Thread.current[:result] = @validator.valid_nonce?
      end
    end
    @threads.each(&:join)
    expect(@threads.select { |thread| thread[:result] }.size).to eq 1
  end

  it 'raises exceptions if invalid' do
    @validator = described_class.new(
      Struct.new(:id, :secret).new(3, 'abc'),
      {
        'HTTP_X_NONCE'   => '1',
        'rack.input'     => 'request body',
        'REQUEST_METHOD' => 'POST',
        'REQUEST_PATH'   => '/gateway/123/orders',
      }
    )
    @validator.env['HTTP_X_SIGNATURE'] = @validator.signature
    expect(@validator.validate!).to eq true
    expect { @validator.validate! }.to raise_error(described_class::InvalidNonce)
    @validator.env['HTTP_X_NONCE'] = '2'
    expect { @validator.validate! }.to raise_error(described_class::InvalidSignature)
  end
end
