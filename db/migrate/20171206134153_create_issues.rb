class CreateIssues < ActiveRecord::Migration
  def change
    create_table :issues, primary_key: :issue_id do |t|
      t.integer :inventory_id
      t.integer :location_id
      t.integer :issued_to
      t.integer :quantity
      t.datetime :issue_date
      t.integer :issued_by
      t.boolean :voided , :default => false
      t.timestamps null: false
    end
  end
end
