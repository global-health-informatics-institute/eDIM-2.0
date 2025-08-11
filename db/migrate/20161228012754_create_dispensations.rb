class CreateDispensations < ActiveRecord::Migration
  def change
    create_table :dispensations,:primary_key => :dispensation_id do |t|
      t.integer :rx_id
      t.string :inventory_id
      t.integer :patient_id
      t.integer :quantity
      t.datetime :dispensation_date
      t.integer :dispensed_by
      t.boolean :voided , :default => false
      t.timestamps null: false
    end
  end
end
