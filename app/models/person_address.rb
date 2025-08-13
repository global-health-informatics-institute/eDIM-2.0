class PersonAddress < ActiveRecord::Base
  establish_connection Registration

  self.table_name = "person_address"
  self.primary_key = "person_address_id"

  # Correct default_scope
  default_scope { order(preferred: :desc) }

  belongs_to :person, -> { where(voided: 0) }, foreign_key: :person_id

  def self.find_most_common(field_name, search_string)
    find_by_sql([<<-SQL, "%#{search_string}%"])
      SELECT DISTINCT #{field_name} AS #{field_name}, person_address_id AS id
      FROM person_address
      WHERE voided = 0 AND #{field_name} LIKE ?
      GROUP BY #{field_name}
      ORDER BY INSTR(#{field_name}, "#{search_string}") ASC,
               COUNT(#{field_name}) DESC,
               
               #{field_name} ASC
      LIMIT 10
    SQL
  end
end