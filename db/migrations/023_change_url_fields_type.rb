Sequel.migration do

  up do
    alter_table(:gateways) do
      set_column_type :callback_url, String, text: true
    end
    alter_table(:orders) do
      set_column_type :callback_url, String, text: true
    end
  end

  down do
    alter_table(:gateways) do
      set_column_type :callback_url, String, size: 255
    end
    alter_table(:orders) do
      set_column_type :callback_url, String, size: 255
    end
  end
end
