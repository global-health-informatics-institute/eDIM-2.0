class GlobalProperty < ActiveRecord::Base
  establish_connection Registration
  self.table_name = "global_property"
  self.primary_key = "property"

  def to_s
    return "#{property}: #{property_value}"
  end

end
