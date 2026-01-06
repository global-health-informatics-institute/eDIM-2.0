class CreateRole < ActiveRecord::Migration[7.0]
  def change
    create_table :role, id: false do |t|
      t.string :role, null: false
      t.string :description
      t.integer :creator
      t.datetime :date_created
      t.boolean :voided, default: false
    end

    execute "ALTER TABLE role ADD PRIMARY KEY (role);"
  end
end