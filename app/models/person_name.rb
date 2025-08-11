class PersonName < ActiveRecord::Base
  establish_connection Registration
  self.table_name = "person_name"
  self.primary_key = "person_name_id"

  include Openmrs
  before_create :before_create
  before_update :before_save
  before_save :before_save

  default_scope { order('person_name.preferred DESC') }
  belongs_to :person, -> { where "voided = 0" }, :foreign_key => :person_id
  has_one :person_name_code, :foreign_key => :person_name_id # no default scope

  def self.find_most_common(field_name, search_string)
    return self.find_by_sql([
                                "SELECT DISTINCT #{field_name} AS #{field_name}, #{self.primary_key} AS id \
     FROM person_name \
     INNER JOIN person ON person.person_id = person_name.person_id \
     WHERE person.voided = 0 AND person_name.voided = 0 AND #{field_name} LIKE ? \
     GROUP BY #{field_name} ORDER BY INSTR(#{field_name},\"#{search_string}\") ASC, COUNT(#{field_name}) DESC, #{field_name} ASC LIMIT 10", "%#{search_string}%"])
  end
end
