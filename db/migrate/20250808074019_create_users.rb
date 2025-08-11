class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users, id: false do |t|
      t.primary_key :user_id
      t.integer :person_id
      t.string  :username, null: false
      t.string  :password, null: false
      t.string  :salt
      t.boolean :voided, default: false
      t.integer :creator
      t.datetime :date_created
      t.datetime :date_changed
      t.integer :changed_by
      t.boolean :retired, default: false
      t.integer :retired_by
      t.datetime :date_retired
      t.string :retire_reason

      t.timestamps
    end

    add_index :users, :username, unique: true
    add_index :users, :person_id
  end
end