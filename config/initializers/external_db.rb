#Definition details for separate db connections

Registration = YAML.load(
  ERB.new(File.read(Rails.root.join("config", "database.yml"))).result,
  aliases: true
)['billing_import']