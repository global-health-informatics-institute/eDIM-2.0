module ApplicationHelper
  def title(page_title, options={})
    content_for(:title, page_title.to_s)
    return content_tag(:h1, page_title, options)
  end

  def drug_categories
    DrugCategory.where(:voided => false).collect{|x| x.category}
  end

  def current_drug_categories
    active_category = Drug.select("DISTINCT drug_category_id").collect{|x| x.drug_category_id}
    DrugCategory.where(drug_category_id: active_category).pluck(:category)
  end

  def dose_forms
     JSON.parse(File.open("#{Rails.root}/db/app_options.json").read)["dose_forms"] rescue []
  end

  def dose_units
    items = JSON.parse(File.open("#{Rails.root}/db/app_options.json").read)["dose_units"] rescue []
  end

  def languages
    items = JSON.parse(File.open("#{Rails.root}/db/app_options.json").read)["languages"] rescue []
  end

  def has_prescribe
    YAML.load_file("#{Rails.root}/config/application.yml")['has_prescribing'] rescue false
  end

  def facility_name
    YAML.load_file("#{Rails.root}/config/application.yml")['facility_name']
  end

  def anonymous_dispensation
    YAML.load_file("#{Rails.root}/config/application.yml")['allow_anonymous_dispense'] rescue false
  end

  def user_roles
    return ["Administrator", "Pharmacist"]
  end

  def report_options
    return [["daily", t('forms.options.daily')],["weekly",t('forms.options.weekly')],
            ["monthly", t('forms.options.monthly')], ["range", t('forms.options.range')]]
  end

  def version
    style = "style='background-color:red;'" unless session[:datetime].blank?
    "eDIM: - <span #{style}>#{(session[:datetime].to_date rescue Date.today).strftime('%A, %d-%b-%Y')}</span>&nbsp;&nbsp;"
  end

  def welcome_message
    'Muli bwanji, enter your user information or scan your id card.'
  end

  def current_location
    @current_location ||= Location.find(session[:location]) if session[:location]
  end


end
