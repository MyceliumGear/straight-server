Sequel.migration do
  up do
    drop_index :gateways, :name
  end

  down do
    add_index :gateways, :name, unique: true
  end
end
