class CreatePersonName < ActiveRecord::Migration
  def change
    create_table :person_name, id: false do |t|
      t.primary_key :person_name_id
      t.integer :person_id, null: false
      t.string  :given_name
      t.string  :middle_name
      t.string  :family_name
      t.string  :family_name2
      t.string  :family_name_suffix
      t.boolean :preferred, default: false
      t.boolean :voided, default: false
      t.integer :creator
      t.datetime :date_created
      t.integer :changed_by
      t.datetime :date_changed

      t.timestamps
    end

    add_index :person_name, :person_id
  end
end