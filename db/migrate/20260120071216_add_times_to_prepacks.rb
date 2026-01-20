class AddTimesToPrepacks < ActiveRecord::Migration[7.0]
  def change
    add_column :prepacks, :times, :json
  end
end
