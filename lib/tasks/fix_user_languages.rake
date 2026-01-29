namespace :users do
  desc "Set default language preferences for users without language settings"
  task fix_languages: :environment do
    puts "Setting default language preferences for users..."
    
    User.where(retired: [false, nil]).find_each do |user|
      language_property = user.user_properties.find_by(property: 'defaultLocale')
      
      if language_property.nil?
        user.user_properties.create!(
          property: 'defaultLocale',
          property_value: 'en'
        )
        puts "Set default language 'en' for user: #{user.username}"
      else
        puts "User #{user.username} already has language preference: #{language_property.property_value}"
      end
    end
    
    puts "Finished setting default language preferences."
  end
end