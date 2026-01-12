class AddDeletedToPrepackLabels < ActiveRecord::Migration[7.0]
  def change
    add_column :prepack_labels, :deleted, :boolean, default: false
  end
end
