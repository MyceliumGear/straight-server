Sequel.migration do

  up do
    add_column :gateways, :after_payment_redirect_to, String, text: true
    add_column :gateways, :auto_redirect, TrueClass, default: false
    add_column :orders, :after_payment_redirect_to, String, text: true
    add_column :orders, :auto_redirect, TrueClass, default: false
  end

  down do
    drop_column :gateways, :after_payment_redirect_to
    drop_column :gateways, :auto_redirect
    drop_column :orders, :after_payment_redirect_to
    drop_column :orders, :auto_redirect
  end

end
