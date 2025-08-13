class Patient < ActiveRecord::Base
  establish_connection Registration
  self.table_name = "patient"
  self.primary_key = "patient_id"

has_one :person, -> { where(voided: 0) }, foreign_key: :person_id, primary_key: :patient_id

  # Identifiers directly on Patient
  has_many :patient_identifiers, -> { where(voided: 0) }, foreign_key: :patient_id, dependent: :destroy

  # Associations through Person
  has_many :names, -> { where(voided: 0) }, through: :person, source: :names
  has_many :addresses, -> { where(voided: 0) }, through: :person, source: :addresses
  has_many :person_attributes, -> { where(voided: 0) }, through: :person, source: :person_attributes
  
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
    id = national_id
    return nil unless id

    if id =~ /^PT(\d{2})(\d{4,})$/
      "PT#{$1}-#{$2}"
    else
      id
    end
  end

  def national_id
    self.patient_identifiers
        .find_by_identifier_type(PatientIdentifierType.find_by_name("National id").id)
        &.identifier
  end

  def current_district
    self.addresses.first.state_province rescue ""
  end

  def current_residence
    self.addresses.first.city_village rescue ""
  end

  def current_address
    addr = addresses.order(preferred: :desc, date_created: :desc).first
    return "" unless addr
    [addr.address2, addr.city_village].reject(&:blank?).join(", ")
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
