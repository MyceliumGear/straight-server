Sequel.migration do

  up do
    create_table :transactions do
      primary_key :id
      foreign_key :order_id, :orders, on_delete: :cascade, on_update: :cascade
      String :tid, null: false
      Bignum :amount, null: false
      Integer :confirmations
      Integer :block_height
      DateTime :created_at, null: false
      DateTime :updated_at
    end
    add_index :transactions, :id, unique: true
    add_index :transactions, :order_id
    add_index :transactions, :tid
  end

  down do
    drop_table :transactions
  end

end
