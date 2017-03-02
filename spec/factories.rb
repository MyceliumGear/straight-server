FactoryGirl.define do

  factory :order, class: StraightServer::Order do
    sequence(:id)          { |i| i }
    sequence(:keychain_id) { |i| i }
    amount 10
    gateway_id 1
    address { StraightServer::GatewayOnConfig.find_by_id(1).address_provider.new_address(keychain_id: keychain_id) }
    after_payment_redirect_to 'http://localhost:3000/my_app/my_own_page'
    auto_redirect true
    to_create { |order| order.save }

    factory :order_without_redirect_to_attrs do
      after_payment_redirect_to nil
      auto_redirect nil
    end
  end

  factory :gateway_on_db, class: StraightServer::GatewayOnDB do
    confirmations_required 0
    pubkey 'xpub6Arp6y5VVQzq3LWTHz7gGsGKAdM697RwpWgauxmyCybncqoAYim6P63AasNKSy3VUAYXFj7tN2FZ9CM9W7yTfmerdtAPU4amuSNjEKyDeo6'
    order_class 'StraightServer::Order'
    secret 'secret'
    name { |i| "name_#{i}" }
    check_signature false
    exchange_rate_adapter_names %w(Bitpay Coinbase Bitstamp)
    active true
  end

end
