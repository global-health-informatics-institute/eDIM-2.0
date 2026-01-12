class AddVoidedToPrepackLabels < ActiveRecord::Migration[7.0]
  def change
    add_column :prepack_labels, :voided, :boolean, default: false
  end
end
