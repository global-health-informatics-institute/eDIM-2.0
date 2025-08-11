class LocationTagMap < ActiveRecord::Base
  establish_connection Registration
  self.table_name = "location_tag_map"
  self.primary_keys = :location_tag_id, :location_id
  belongs_to :location_tag
  belongs_to :location
end
