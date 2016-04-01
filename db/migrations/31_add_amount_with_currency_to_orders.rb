Sequel.migration do
  up do
    add_column :orders, :amount_with_currency, String
  end

  down do
    drop_column :orders, :amount_with_currency
  end
end
