class AddDispensedByToPrepackLabels < ActiveRecord::Migration[7.0]
  def change
    add_column :prepack_labels, :dispensed_by, :integer
  end
end
