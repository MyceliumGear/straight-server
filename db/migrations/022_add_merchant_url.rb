Sequel.migration do

  up do
    add_column :gateways, :merchant_url, String, text: true
  end

  down do
    drop_column :gateways, :merchant_url
  end

end
