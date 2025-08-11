class CreateUserRole < ActiveRecord::Migration
  def change
    create_table :user_role, id: false do |t|
      t.integer :user_id, null: false
      t.string  :role,    null: false
      t.integer :creator
      t.datetime :date_created
      t.boolean :voided, default: false
    end

    # Composite primary key (emulated with a unique index)
    add_index :user_role, [:user_id, :role], unique: true
    add_index :user_role, :user_id
    add_index :user_role, :role
  end
end