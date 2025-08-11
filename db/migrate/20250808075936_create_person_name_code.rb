class CreatePersonNameCode < ActiveRecord::Migration
  def change
    create_table :person_name_code, id: false do |t|
      t.primary_key :person_name_code_id
      t.integer :person_name_id, null: false
      t.string :given_name_code
      t.string :middle_name_code
      t.string :family_name_code
      t.string :family_name2_code
      t.string :family_name_suffix_code

      t.timestamps
    end

    add_index :person_name_code, :person_name_id
  end
end