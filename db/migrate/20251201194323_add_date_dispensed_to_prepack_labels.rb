class AddDateDispensedToPrepackLabels < ActiveRecord::Migration[7.0]
  def change
    add_column :prepack_labels, :date_dispensed, :datetime
  end
end
