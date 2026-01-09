class CreateAppOptions < ActiveRecord::Migration[7.0]
  def change
    create_table :app_options do |t|
      t.string :name, null: false
      t.string :value

      t.timestamps
    end

    add_index :app_options, :name, unique: true
  end
end