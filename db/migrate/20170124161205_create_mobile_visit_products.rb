<<<<<<< HEAD
class CreateMobileVisitProducts < ActiveRecord::Migration[7.0]
=======
class CreateMobileVisitProducts < ActiveRecord::Migration[4.2]
>>>>>>> 2d57a4e (clean up migration versions)
  def change
    create_table :mobile_visit_products,:primary_key => :mvp_id do |t|
			t.integer :mobile_visit_id
			t.string :gn_identifier
			t.integer :amount_taken
			t.integer :amount_used
			t.boolean :voided, :default => false
      t.timestamps null: false
    end
  end
end
