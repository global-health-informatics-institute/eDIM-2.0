class AddParLevelToDrugs < ActiveRecord::Migration
  def change
    add_column :drugs, :par_level, :integer
  end
end
