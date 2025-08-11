class CreateUserProperty < ActiveRecord::Migration
  def change
    create_table :user_property, id: false do |t|
      t.integer :user_id, null: false
      t.string  :property, null: false
      t.text    :property_value
      t.integer :creator
      t.datetime :date_created
      t.boolean :voided, default: false
    end

    # Simulate composite PK with unique index
    add_index :user_property, [:user_id, :property], unique: true
    add_index :user_property, :user_id
  end
end