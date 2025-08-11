class Person < ActiveRecord::Base
  establish_connection Registration
  self.table_name = "person"
  self.primary_key = "person_id"

  include Openmrs

  before_create :before_create
  before_update :before_save
  before_save :before_save

  has_one :patient,-> {where voided: 0}, :foreign_key => :patient_id, :dependent => :destroy
  has_many :names, :class_name => 'PersonName', :foreign_key => :person_id, :dependent => :destroy
  has_many :addresses, :class_name => 'PersonAddress', :foreign_key => :person_id, :dependent => :destroy
  has_many :person_attributes, :class_name => 'PersonAttribute', :foreign_key => :person_id

  def display_age
    age_in_days = (Date.current - self.birthdate).to_i

    if age_in_days < 31
      return age_in_days.to_s + " days"
    elsif age_in_days < 548
      years = (Date.today.year - self.birthdate.year)
      months = (Date.today.month - self.birthdate.month)
      return ((years * 12) + months).to_s + " months"
    else
      return (age_in_days / 365).to_s + " years"
    end
  end

end
