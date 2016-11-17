# bundle exec sequel -d postgres://postgres@localhost/straight_server_dev > db/schema.rb

Sequel.migration do
  change do
    create_table(:gateways, :ignore_index_errors=>true) do
      primary_key :id
      Integer :confirmations_required, :default=>0, :null=>false
      Integer :last_keychain_id, :default=>0, :null=>false
      String :pubkey, :text=>true
      String :order_class, :text=>true, :null=>false
      String :secret, :text=>true, :null=>false
      String :name, :text=>true, :null=>false
      String :default_currency, :default=>"BTC", :text=>true
      String :callback_url, :text=>true
      TrueClass :check_signature, :default=>false, :null=>false
      String :exchange_rate_adapter_names, :text=>true
      DateTime :created_at, :null=>false
      DateTime :updated_at
      Integer :orders_expiration_period
      TrueClass :check_order_status_in_db_first
      TrueClass :active, :default=>true
      String :order_counters, :text=>true
      String :hashed_id, :text=>true
      String :address_provider, :default=>"Bip32", :text=>true, :null=>false
      String :address_derivation_scheme, :text=>true
      TrueClass :test_mode, :default=>false
      Integer :test_last_keychain_id, :default=>0, :null=>false
      String :test_pubkey, :text=>true
      String :after_payment_redirect_to, :text=>true
      TrueClass :auto_redirect, :default=>false
      String :merchant_url, :text=>true
      TrueClass :allow_links, :default=>false
      String :back_url, :text=>true
      String :custom_css_url, :text=>true
      TrueClass :donation_mode, :default=>false
      
      index [:hashed_id]
      index [:id], :unique=>true
      index [:pubkey], :unique=>true
    end
    
    create_table(:orders, :ignore_index_errors=>true) do
      primary_key :id
      String :address, :text=>true, :null=>false
      String :tid, :text=>true
      Integer :status, :default=>0, :null=>false
      Integer :keychain_id, :null=>false
      Bignum :amount, :null=>false
      Integer :gateway_id, :null=>false
      String :data, :text=>true
      String :callback_response, :text=>true
      DateTime :created_at, :null=>false
      DateTime :updated_at
      String :payment_id, :text=>true
      String :description, :text=>true
      Integer :reused, :default=>0
      String :callback_data, :text=>true
      Bignum :amount_paid
      String :callback_url, :text=>true
      String :title, :text=>true
      TrueClass :test_mode, :default=>false
      String :after_payment_redirect_to, :text=>true
      TrueClass :auto_redirect, :default=>false
      Integer :block_height_created_at
      String :amount_with_currency, :text=>true
      
      index [:address]
      index [:id], :unique=>true
      index [:keychain_id, :gateway_id]
      index [:payment_id], :unique=>true
    end
    
    create_table(:schema_info) do
      Integer :version, :default=>0, :null=>false
    end
    
    create_table(:transactions, :ignore_index_errors=>true) do
      primary_key :id
      foreign_key :order_id, :orders, :key=>[:id], :on_delete=>:cascade, :on_update=>:cascade
      String :tid, :text=>true, :null=>false
      Bignum :amount, :null=>false
      Integer :confirmations
      Integer :block_height
      DateTime :created_at, :null=>false
      DateTime :updated_at
      
      index [:id], :unique=>true
      index [:order_id]
      index [:tid]
    end
  end
end
