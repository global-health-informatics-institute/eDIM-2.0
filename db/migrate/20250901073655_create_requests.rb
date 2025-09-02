class CreateRequests < ActiveRecord::Migration[7.0]
  def change
    create_table :requests do |t|
      t.integer :drug_id, null: false
      t.integer :location_id, null: false   # where request was made
      t.integer :quantity, null: false
      t.boolean :fulfilled, default: false
      t.datetime :fulfilled_at
      t.integer :fulfilled_by   # user_id who fulfilled

      t.timestamps
    end
  end
end