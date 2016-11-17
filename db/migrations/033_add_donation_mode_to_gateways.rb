Sequel.migration do
  up do
    add_column :gateways, :donation_mode, TrueClass, default: false
  end

  down do
    drop_column :gateways, :donation_mode
  end
end
