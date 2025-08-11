# Delete all existing records to start fresh
#UserRole.delete_all
#UserProperty.delete_all
#ser.delete_all
#Role.delete_all
#PersonName.delete_all
#Person.delete_all
#Location.delete_all

# Create location
# Create or find location
location = Location.find_or_create_by!(location_id: 1) do |loc|
  loc.name = 'Wandikwe Health Center'
  loc.description = 'Remote health center'
  loc.city_village = 'Lilongwe'
  loc.state_province = 'Central'
  loc.country = 'Malawi'
  loc.creator = 1
  loc.date_created = Time.now
  loc.date_changed = Time.now
  loc.uuid = SecureRandom.uuid
end

# Seed LocationTag for 'workstation location'
workstation_tag = LocationTag.find_or_create_by!(
  location_tag_id: 1,
  name: 'workstation location'
)

# Link the location to the workstation location tag via LocationTagMap
LocationTagMap.find_or_create_by!(
  location_tag_id: workstation_tag.location_tag_id,
  location_id: location.location_id
)


# Create role
admin_role = Role.create!(
  role: "admin",
  description: "Administrator"
)

# Create person and name
person = Person.create!(
  person_id: 1,
  gender: "M",
  birthdate: "1990-01-01",
  voided: false,
  creator: 1,
  date_created: Time.now
)

PersonName.create!(
  person_name_id: 1,
  person_id: person.person_id,
  given_name: "Shadreck",
  family_name: "Khamba",
  preferred: true,
  voided: false,
  creator: 1,
  date_created: Time.now
)

# Create the user (with password encryption logic if applicable)
user = User.new(
  user_id: 1,
  username: "admin",
  person_id: person.person_id,
  voided: false,
  creator: 1,
  date_created: Time.now
)

# Use setter so that encryption is handled by model
user.password = "password"
user.save!

# Link user to role
UserRole.create!(
  user_id: user.user_id,
  role: admin_role.role
)

puts "Seeded initial user: admin / password"