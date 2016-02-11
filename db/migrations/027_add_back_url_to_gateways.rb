Sequel.migration do
  up do
    add_column :gateways, :back_url, String, text: true
  end

  down do
    drop_column :gateways, :back_url
  end
end
