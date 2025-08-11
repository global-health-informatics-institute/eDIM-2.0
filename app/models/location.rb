class Location < ActiveRecord::Base
  establish_connection Registration
  self.table_name = "location"
  self.primary_key = "location_id"
  include Openmrs

  cattr_accessor :current_location
  before_create :before_create
  before_update :before_save
  before_save :before_save

  def site_id
    Location.current_health_center.location_id.to_s
  rescue
    raise "The id for this location has not been set (#{Location.current_location.name}, #{Location.current_location.id})"
  end

  def children
    return [] if self.name.match(/ - /)
    Location.all.where("name LIKE ?","%" + self.name + " - %")
  end

  def parent
    return nil unless self.name.match(/(.*) - /)
    Location.find_by_name($1)
  end

  def site_name
    self.name.gsub(/ -.*/,"")
  end

  def related_locations_including_self
    if self.parent
      return self.parent.children + [self]
    else
      return self.children + [self]
    end
  end

  def related_to_location?(location)
    self.site_name == location.site_name
  end

  def self.current_health_center
    @@current_health_center ||= Location.find(GlobalProperty.find_by_property("current_health_center_id").property_value) rescue self.current_location
  end

  def self.current_arv_code
    current_health_center.neighborhood_cell rescue nil
  end

  def is_a_workstation?
    workstation_id = LocationTag.select(:location_tag_id).where(name: ['workstation location']).collect{|x| x.location_tag_id}
    tag_map = LocationTagMap.where(location_id: self.location_id, location_tag_id: workstation_id)
    return tag_map.blank?
  end
end

