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
    @validator                         = described_class.new(
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

  it 'accepts superuser signature' do
    @validator = described_class.new(
      Struct.new(:secret).new(nil),
      {
        'HTTP_X_NONCE'   => '42',
        'rack.input'     => '',
        'REQUEST_METHOD' => 'POST',
        'REQUEST_URI'    => '/gateways/abc/orders/123/reprocess',
      }
    )
    expect(@validator).to receive(:valid_signature?).exactly(5).times.and_call_original
    expect(@validator).to receive(:superuser_signature?).exactly(4).times.and_call_original
    expect(@validator.class).to receive(:superuser_signature?).exactly(1).times.and_call_original

    @validator.env['HTTP_X_SIGNATURE'] = 'buro4shceFMpywDVKeh8x3ohcQawStEhrERnHhBYAabnAb0ZZmpWZrS81YKOsWpZwMW+S5t1A0x2fFmXOH6bO0yUbA2AOCtIF2InzHAh43qls/RUVq1pFiX15MBMhHSJhdb5o3UBQ4N6sTtYwXtIPZN2tbvlmoq2D1TWTKXrdRJQ7Oc5LJ/wzPTtuTH+RIhH/8wvpU2cL38M7dfiHDNIscY00lSrn+wiItwuH7TKscNTmJ3WSbVqpa2GYUSh0W8nbvq2iT77BMk2pB2i23dXu+dqaJN1qScxeXweWoGwHgvM5zchIBCkfz4kn5n6MFPR2MDbOmEE2ZxDMbIWcgeaaf9UYhy981huDacqXTLvQJNcTxAw+WDx6CWZ/YnLB/vuf8B7QqTby69Bu90R0UOTJO4NJ1U4ozKZgQkJHTOwOeLnX0fWkSz3GXqu03nShvNGFnLAsMXRj29x1sG6Akn9KC38kN7hxJ885T2n8nGRD5I51FGJs1OteXTngJfysjmI1uaLl53uGf/FApnLW5i4Ao96Nd6XpqghrGMXX1ohyET0zmpQIHEyF37121WckS3lgPWB3Al4nWpu8TPPD6DNlVaseSH+TSjE2JlvP06iZn0R+TPW2HpA6GSbfxw78nqbaK5BB5gTQbQbAmZr5NKiaQPNGB41bd2WEMkIlp5RwCs='

    StraightServer::Config[:superuser_public_key] = nil
    expect(@validator.valid_signature?).to eq nil

    StraightServer::Config[:superuser_public_key] = 'invalid'
    expect(@validator.valid_signature?).to eq nil

    StraightServer::Config[:superuser_public_key] = "-----BEGIN PUBLIC KEY-----\nMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAwjrPgei0ijl0JWqwf3IJ\ncUdSyipOvlf/uEUXi8NhcOlenr+1sCet5MDwmOSkc3Y42fifmAkDWUsvfv/hVImC\njfIema/3qvNYYdknBf1O4i4GYhHBI4V/iK4QPKxdiYobTN3pyQmjDXf6Nrkbp3wb\nyWLNM2A8l51YhN7/Fi6dozy7yZKSN3yr5ZpGAPjNZkqa/w5yOdfqC9HowA7FBT7C\nftkzPJ43S49cQM4tqrNFABpOLCgFSIw4yFCLRY99IIh2dBosH7vKQ+iSdodIFyq+\nqL9e0Z0J3FftB7hYK7MedBwzX/PjxI/lsspdpPuzc/WAWPx8/YLlE6lEQ9MpOvNp\nWUNt689EkbRWrtHIZ3QTDH0z47tFkNXsfgyDeBU6P/jTshNZrju4RgoJCAvP+Xhx\n3ErMIogmeG7OrWWPjCflwCX2c90r8l/uoCe6ZANo1OpjBe9yV6jWD3U477tkNTqm\nEeYQDxHFTB0iF528tP2+mTWef0ScfM5lCgTpa2R568UsY1y1PiD88fZp5zao/KBq\ngfkWjQ47ZOi3cX2h2iQQ428WnrodwkSULpajnP10zIbpPtSZv8KxZV8Xqvmf/R8N\nIJTqfyxjWZw3wXneXcwNyQPM+XF6Y+fr6SnctW8LKesVh67xwFgBFHESy5dAwWSM\np2zYfsxdrEic5nlVBeG49yUCAwEAAQ==\n-----END PUBLIC KEY-----\n"
    expect(@validator.valid_signature?).to eq true

    @validator.env['HTTP_X_SIGNATURE'] = nil
    expect(@validator.valid_signature?).to eq false

    @validator.env['HTTP_X_SIGNATURE'] = 'invalid'
    expect(@validator.valid_signature?).to eq false
  end

  it 'raises exceptions if invalid' do
    @validator                         = described_class.new(
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
    @validator.env['HTTP_X_NONCE'] = '2'
    expect { @validator.validate! }.to raise_error(described_class::InvalidSignature)
  end
end
