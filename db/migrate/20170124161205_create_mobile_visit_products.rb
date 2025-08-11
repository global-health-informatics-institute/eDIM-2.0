class CreateMobileVisitProducts < ActiveRecord::Migration
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
