class TrimWhitespaceFromDrugsAndCategories < ActiveRecord::Migration[7.0]
  def up
    # Trim whitespace from drug names
    execute "UPDATE drugs SET name = TRIM(name) WHERE name != TRIM(name)"
    
    # Trim whitespace from drug category names
    execute "UPDATE drug_categories SET category = TRIM(category) WHERE category != TRIM(category)"
  end
  
  def down
    # This migration cannot be reversed as we don't know the original whitespace
    raise ActiveRecord::IrreversibleMigration
  end
end
