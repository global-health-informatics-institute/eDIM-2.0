class CreateDrugThresholds < ActiveRecord::Migration[4.2]
  def change
    create_table :drug_thresholds, :primary_key => :threshold_id do |t|
      t.string :drug_id
      t.integer :threshold
      t.boolean :voided, :default => false
      t.timestamps null: false
    end
  end
end
