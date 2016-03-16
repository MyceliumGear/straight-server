Sequel.migration do
  up do
    add_column :orders, :exchange_rate, BigDecimal
    add_column :orders, :currency, String
  end

  down do
    drop_column :orders, :exchange_rate
    drop_column :orders, :currency
  end
end
