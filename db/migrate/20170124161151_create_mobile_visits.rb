class CreateMobileVisits < ActiveRecord::Migration
  def change
    create_table :mobile_visits,:primary_key => :mobile_visit_id do |t|
      t.date :visit_date
			t.integer :visit_supervisor
			t.boolean :voided, :default => false
      t.timestamps null: false
    end
  end
end
