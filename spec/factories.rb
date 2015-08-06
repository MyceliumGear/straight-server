FactoryGirl.define do

  factory :order, class: StraightServer::Order do
    sequence(:id)          { |i| i }
    sequence(:keychain_id) { |i| i }
    sequence(:address)     { |i| "address_#{i}" }
    amount 10
    gateway_id 1
    after_payment_redirect_to 'http://localhost:3000/my_app/my_own_page'
    auto_redirect true
    to_create { |order| order.save }

    factory :order_without_redirect_to_attrs do
      after_payment_redirect_to nil
      auto_redirect nil
    end
  end

end
