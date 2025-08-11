class CreateDrugCategories < ActiveRecord::Migration
  def change
    create_table :drug_categories, :primary_key =>  :drug_category_id do |t|
      t.string  :category
      t.boolean :voided, default: false
      t.timestamps null: false
    end
  end
end
