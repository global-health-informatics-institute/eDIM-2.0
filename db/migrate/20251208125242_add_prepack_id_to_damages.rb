class AddPrepackIdToDamages < ActiveRecord::Migration[7.0]
  def change
    add_reference :damages, :prepack, foreign_key: true, index: true
  end
end
