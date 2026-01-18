class CreateEdimPatients < ActiveRecord::Migration[7.0]
  def change
    create_table :edim_patients, id: false do |t|
      t.integer :patient_id, null: false, primary_key: true

      # Basic identity
      t.string  :given_name,  limit: 50
      t.string  :family_name, limit: 50
      t.string  :full_name,   limit: 120

      # Demographics
      t.string  :gender, limit: 1
      t.date    :birthdate

      # Identifier used to scan
      t.string  :identifier, limit: 50

      t.timestamps
    end

    add_index :edim_patients, :identifier, unique: true
  end
end