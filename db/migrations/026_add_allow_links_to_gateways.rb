Sequel.migration do

  up do
    add_column :gateways, :allow_links, TrueClass, default: false
  end

  down do
    drop_column :gateways, :allow_links
  end

end
