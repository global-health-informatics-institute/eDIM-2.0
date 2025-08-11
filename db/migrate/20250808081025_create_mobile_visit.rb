class CreateMobileVisit < ActiveRecord::Migration
  def change
    create_table :mobile_visit do |t|
      t.date :visit_date, null: false
      t.integer :visit_supervisor, null: false
      t.text :notes
      t.boolean :voided, default: false
      t.integer :creator
      t.datetime :date_created
      t.integer :changed_by
      t.datetime :date_changed

      t.timestamps
    end

    add_index :mobile_visit, :visit_supervisor
  end
end