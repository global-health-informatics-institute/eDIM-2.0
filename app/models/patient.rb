class Patient < ActiveRecord::Base
  establish_connection Registration
  self.table_name = "patient"

  has_one :person, -> { where "voided = 0" }, :foreign_key => :person_id
  has_many :patient_identifiers,-> { where "voided = 0" }, :foreign_key => :patient_id, :dependent => :destroy
  has_many :names,-> { where "voided = false"}, :class_name => 'PersonName', :foreign_key => :person_id, :dependent => :destroy
  has_many :addresses,-> { where "voided = false" }, :class_name => 'PersonAddress', :foreign_key => :person_id, :dependent => :destroy
  has_many :person_attributes,-> { where "voided = 0" }, :class_name => 'PersonAttribute', :foreign_key => :person_id

  def full_name
    names = self.names.first
    return (names.given_name || '') + " " + (names.family_name || '')
  end

  def first_names
    names = self.names.first
    return (names.given_name || '') + " " + (names.middle_name || '')
  end

  def last_names
    names = self.names.first
    return (names.family_name2 || '') + " " + (names.family_name || '')
  end
  def formatted_pnid
    Misc.dash_formatter(self.patient_identifiers.find_by_identifier_type(PatientIdentifierType.find_by_name("National id").id).identifier) rescue nil
  end

  def national_id
    self.patient_identifiers.find_by_identifier_type(PatientIdentifierType.find_by_name("National id").id).identifier rescue nil
  end

  def current_district
    self.person.addresses.first.state_province rescue ""
  end

  def current_residence
    self.person.addresses.first.city_village rescue ""
  end

  def current_address
    address = self.current_district rescue ""
    if address.blank?
      address = self.current_residence rescue ""
    else
      address += ", " + self.current_residence unless self.current_residence.blank?
    end
    return address
  end

  def gender
    self.person.gender
  end

  def sex
    self.person.gender == 'F' ? 'Female' : 'Male'
  end

  def age
    self.person.display_age rescue ''
  end

end
