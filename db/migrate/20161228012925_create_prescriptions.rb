class CreatePrescriptions < ActiveRecord::Migration
  def change
    create_table :prescriptions, :primary_key => :rx_id do |t|
      t.integer :patient_id
      t.integer :drug_id
      t.datetime :date_prescribed
      t.integer :quantity
      t.integer :amount_dispensed
      t.string :directions
      t.integer :provider_id
      t.boolean :voided, :default => false
      t.timestamps null: false    end
  end
end
