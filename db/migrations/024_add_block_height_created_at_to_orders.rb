Sequel.migration do

  up do
    add_column :orders, :block_height_created_at, Integer
  end

  down do
    drop_column :orders, :block_height_created_at
  end

end
