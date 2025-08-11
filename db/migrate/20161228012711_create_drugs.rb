class CreateDrugs < ActiveRecord::Migration
  def change
    create_table :drugs, :primary_key => :drug_id do |t|
      t.integer :drug_category_id
      t.string :name
      t.string :dose_strength
      t.string :dose_form, null: false
      t.boolean :voided, default: false
      t.timestamps null: false
    end
  end
end
