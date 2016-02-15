Sequel.migration do
  up do
    add_column :gateways, :custom_css_url, String, text: true
  end

  down do
    drop_column :gateways, :custom_css_url
  end
end
