class AddTimesToPrescriptions < ActiveRecord::Migration[6.1]
  def change
    add_column :prescriptions, :times, :string
  end
end