class AddPrescriptionFieldsToPrepacks < ActiveRecord::Migration[7.0]
  def change
    add_column :prepacks, :dose, :decimal
    add_column :prepacks, :duration, :integer
    add_column :prepacks, :frequency, :string
    add_column :prepacks, :administration, :string
  end
end
