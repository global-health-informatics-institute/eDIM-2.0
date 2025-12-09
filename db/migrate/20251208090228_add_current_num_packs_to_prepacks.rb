class AddCurrentNumPacksToPrepacks < ActiveRecord::Migration[7.0]
  def change
    add_column :prepacks, :current_num_packs, :integer, default: 0, null: false
  end
end