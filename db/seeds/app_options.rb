path = Rails.root.join("db", "seeds", "app_options.json")

puts "→ Importing app options"

JSON.parse(File.read(path)).each do |key, value|
  AppOption.find_or_create_by!(name: key) do |opt|
    opt.value = value
  end
end

puts "App options imported"
