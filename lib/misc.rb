#This module includes all functions that may come in handy to do avoid code repetitions

module Misc

  require "i18n"
  def calculate_check_digit(number)
    # This is Luhn's algorithm for checksums
    # http://en.wikipedia.org/wiki/Luhn_algorithm
    # Same algorithm used by PIH (except they allow characters)
    number = number.to_s
    number = number.split(//).collect { |digit| digit.to_i }
    parity = number.length % 2

    sum = 0
    number.each_with_index do |digit,index|
      luhn_transform = ((index + 1) % 2 == parity ? (digit * 2) : digit)
      luhn_transform = luhn_transform - 9 if luhn_transform > 9
      sum += luhn_transform
    end

    checkdigit = (sum * 9 )%10
    return checkdigit
  end

  def self.create_bottle_label(item,bottle_id,expiration_date,qty = nil)

    label = ZebraPrinter::StandardLabel.new
    label.font_size = 4
    label.font_horizontal_multiplier = 1
    label.font_vertical_multiplier = 1
    label.left_margin = 50
    label.draw_barcode(610,30,1,1,2,4,80,false,"#{bottle_id}")
    label.draw_multi_text("#{item}", {:column_width => 520})
    label.draw_multi_text("Inventory #: #{Misc.dash_formatter(bottle_id)}",{:column_width => 520})
    label.draw_multi_text("Quantity : #{qty}",{:column_width => 520}) if !qty.blank?
    label.draw_multi_text("Exp : #{expiration_date.strftime('%m/%Y')}", {:column_width => 520})
    label.print(1)

  end

  def self.create_dispensation_label(item,quantity,directions,patient_name,date)

    label = ZebraPrinter::StandardLabel.new
    label.font_size = 4
    label.font_horizontal_multiplier = 1
    label.font_vertical_multiplier = 1
    label.left_margin = 50
    #label.draw_text("Rx:#{rx_id}",450,10,0,4,1,1,true)
    #label.draw_multi_text("#{Misc.get_facility_name}",{:column_width => 570})
    label.draw_multi_text("Patient: #{patient_name}",{:column_width => 570}) if !patient_name.blank?
    label.draw_multi_text("#{item}",{:column_width => 570})
    label.draw_multi_text("Dir : #{directions}",{:column_width => 570})
    label.draw_multi_text("QTY : #{quantity}",{:column_width => 570})
    label.draw_multi_text("#{date}",{:column_width => 570})
    label.print(1)

  end

  def self.dash_formatter(id)
    return "" if id.blank?
    if id.length > 9
      return id[0..(id.length/3)] + "-" +id[1 +(id.length/3)..(id.length/3)*2]+ "-" +id[1 +2*(id.length/3)..id.length]
    else
      return id[0..(id.length/2)] + "-" +id[1 +(id.length/2)..id.length]
    end
  end

  def self.source_of_meds(patient_id,inventory_id)

    if inventory_id.match(/g/i)
      return "General"
    else
      pmap_med = PmapInventory.where("pap_identifier = ? AND voided = ?", inventory_id, false).pluck(:patient_id)

      if pmap_med.blank?
        return "General"
      else
        if pmap_med.include?(patient_id)
          return "PMAP"
        else
          return "Borrowed"
        end
      end
    end
  end


  def self.calculate_gn_thresholds

    sets = get_threshold_sets

    items = GeneralInventory.where("voided = ?", false).group(:drug_id).sum(:current_quantity)

    (items || []).each do |drug_id, count|
      (sets || []).each do |id,threshold|
        if threshold["items"].include? drug_id
          threshold["count"] += count
        end
      end
    end

    (sets || []).each do |id,set|
      set["items"] = []
    end
    return sets
  end

  def self.create_directions(dose, route, frequency, prn)
    I18n.locale = I18n.default_locale
    routes = {"oral"=>I18n.t('menu.terms.take'), "topical"=>I18n.t('menu.terms.apply'),
              "injection"=>I18n.t('menu.terms.inject'),"respiratory"=>I18n.t('menu.terms.inhale'),"other"=>""}

    frequencies = {"OD"=> I18n.t('forms.options.once_a_day'), "BD"=>I18n.t('forms.options.two_times_a_day'),
                   "TDS"=>I18n.t('forms.options.three_times_a_day'), "QID"=>I18n.t('forms.options.four_times_a_day'),
                   "QHR"=>I18n.t('forms.options.every_hour'), "Q4HRS"=>I18n.t('forms.options.every_four_hours'),
                   "EOD"=>I18n.t('forms.options.every_other_day'),"QN" =>I18n.t('forms.options.every_night'),
                   "Q2HRS"=>I18n.t('forms.options.every_two_hours'), "QWK"=>I18n.t('forms.options.once_a_week')}

    prn = (prn == "PRN" ? I18n.t('forms.options.as_needed') : '')

    return (routes[route.downcase] + " "+ dose.to_s + " " + frequencies[frequency] +" " + prn).titleize
  end

  def get_facility_name
    YAML.load_file("#{Rails.root}/config/application.yml")['facility_name']
  end

  def self.print_location(location_id)
    location = Location.find(location_id)
    label = ZebraPrinter::Label.new(801,329,'026',false)
    label.font_size = 2
    label.font_horizontal_multiplier = 2
    label.font_vertical_multiplier = 2
    label.left_margin = 50
    label.draw_barcode(50,180,0,1,5,15,120,false,"#{location.location_id}")
    label.draw_multi_text("#{location.name}")
    label.print(1)
  end

  def self.bottle_item(route, dose_form)
    forms = %w[Suspension Inhalant Spray Cream Foam Oil Solution Lotion Bar
    Gel Ointment Paste Powder]
    routes = %w[Oral Respiratory Topical]

    if forms.include?(dose_form.titleize) && routes.include?(route.titleize)
      return true
    else
      return false
    end
  end

  private

  def get_facility_phone
    YAML.load_file("#{Rails.root}/config/application.yml")['facility_phone_number']
  end

  def self.get_threshold_sets
    sets = DrugThresholdSet.where("voided = ? ", false).pluck(:threshold_id,:rxaui)

    mappings = {}
    sets.each do | element|
      if mappings[element[0]].blank?
        threshold = DrugThreshold.find(element[0])
        mappings[element[0]] = {"items" => [], "count" => 0,"name" => threshold.drug_name,"threshold" => threshold.threshold}
      end
      mappings[element[0]]["items"] << element[1]
    end
    return mappings
  end
end


