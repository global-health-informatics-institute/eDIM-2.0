puts "Running eDIM seeds..."

# Bootstrap data

location = Location.find_or_create_by!(location_id: 1) do |loc|
  loc.name = 'Dispensary'
  loc.description = 'Wandikweza Health Center Dispensary'
  loc.city_village = 'Lilongwe'
  loc.state_province = 'Central'
  loc.country = 'Malawi'
  loc.creator = 1
  loc.date_created = Time.now
  loc.date_changed = Time.now
  loc.uuid = SecureRandom.uuid
end

workstation_tag = LocationTag.find_or_create_by!(
  location_tag_id: 2,
  name: 'workstation location'
)

LocationTagMap.find_or_create_by!(
  location_tag_id: workstation_tag.location_tag_id,
  location_id: location.location_id
)

admin_role = Role.find_or_create_by!(
  role: "admin"
) do |r|
  r.description = "Administrator"
end

person = Person.find_or_create_by!(person_id: 1) do |p|
  p.gender = "M"
  p.birthdate = "1990-01-01"
  p.voided = false
  p.creator = 1
  p.date_created = Time.now
end

PersonName.find_or_create_by!(
  person_name_id: 1
) do |pn|
  pn.person_id = person.person_id
  pn.given_name = "Shadreck"
  pn.family_name = "Khamba"
  pn.preferred = true
  pn.voided = false
  pn.creator = 1
  pn.date_created = Time.now
end

user = User.find_or_initialize_by(user_id: 1)
if user.new_record?
  user.username = "admin"
  user.person_id = person.person_id
  user.voided = false
  user.creator = 1
  user.date_created = Time.now
  user.password = "password"
  user.save!
end

UserRole.find_or_create_by!(
  user_id: user.user_id,
  role: admin_role.role
)

puts "Core bootstrap data ensured"

# Load data-import seeds

require_relative "seeds/drugs"
require_relative "seeds/cmst"
require_relative "seeds/app_options"

puts "All seeds completed successfully"