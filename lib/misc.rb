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

  def self.create_bottle_label(item, bottle_id, expiration_date, qty = nil)

    label = ZebraPrinter::StandardLabel.new
    label.font_size = 4
    label.font_horizontal_multiplier = 1
    label.font_vertical_multiplier = 1
    label.left_margin = 10
    label.x = label.left_margin

    label_width = 809       
    text_x = 50              
    column_width = 800       
    current_y = 30           

    # Draw text lines
    label.draw_multi_text("#{item}", column_width: column_width, x: text_x, y: current_y)
    current_y += 40

    label.draw_multi_text("Inventory #: #{Misc.dash_formatter(bottle_id)}", column_width: column_width, x: text_x, y: current_y)
    current_y += 40

    if qty.present?
      label.draw_multi_text("Quantity: #{qty}", column_width: column_width, x: text_x, y: current_y)
      current_y += 40
    end

    label.draw_multi_text("Exp: #{expiration_date.strftime('%m/%Y')}", column_width: column_width, x: text_x, y: current_y)
    current_y += 60

    # Center the barcode under the text
    barcode_width_est = 200  
    barcode_x = (label_width - barcode_width_est) / 2

    # Draw barcode
    label.draw_barcode(150, 280, 0, 1, 2, 3, 80, false, "#{bottle_id}")

    label.print(1)
  end

  def self.create_dispensation_label(item, quantity, directions, patient_name, date, pack_id:, bottle_id:, times: [], expiration_date:, pack_index: nil, total_packs: nil)

    label = ZebraPrinter::StandardLabel.new
    label.font_size = 4
    label.font_horizontal_multiplier = 1
    label.font_vertical_multiplier = 1
    label.left_margin = 20
    label.right_margin = 20
    label.x = label.left_margin
    text_column_width = [label.width.to_i - (label.left_margin.to_i + label.right_margin.to_i), 200].max

    # Text content
    id_line = "ID: #{bottle_id}"
    if pack_id.present? && pack_id.start_with?("PK-")
      pack_number = pack_id.to_s.split('-').last
      id_line += "   Pack NO.: #{pack_number}"
    end
    label.draw_multi_text(id_line, column_width: text_column_width)
    label.draw_multi_text("Drug: #{item}", column_width: text_column_width)
    label.draw_multi_text("Dir : #{directions}", column_width: text_column_width)

    # Format dose pattern directly from times hash
    if times.is_a?(Hash)
      dose_pattern = "#{times[:morning] || 0} - #{times[:afternoon] || 0} - #{times[:evening] || 0} - #{times[:night] || 0}"
    else
      dose_pattern = Misc.extract_dose_pattern(directions, times)
    end
    label.draw_multi_text(dose_pattern, column_width: text_column_width) if dose_pattern.present?

    label.draw_multi_text("QTY : #{quantity}", column_width: text_column_width)

    expiry_text = if expiration_date.blank? || expiration_date.to_s.strip.downcase.in?(%w[nil null])
      "Expiry: Unknown"
    else
      "Expiry: #{expiration_date.strftime('%d/%m/%Y')}"
    end
    label.draw_multi_text(expiry_text, column_width: text_column_width)

    #label.draw_multi_text("Date: #{date.strftime('%d/%m/%Y')}", column_width: 2700)

    if pack_index && total_packs && (!pack_id.present? || !pack_id.start_with?("PK-"))
      label.draw_multi_text("Pack #{pack_index} of #{total_packs}", column_width: text_column_width)
    end

    # Only draw barcode for PREPACK labels
    if pack_id.present? && pack_id.start_with?("PK-")

      label.draw_barcode(150, 280, 0, 1, 2, 3, 80, false, pack_id)
    else
      puts "SKIPPING BARCODE for: #{pack_id}"
    end

    label.print(1)
  end

  def self.extract_dose_pattern(directions, times = [])
    return "" if directions.blank?

    normalized = directions.downcase.strip

    dose_match = normalized.match(/take\s+(\d+)/)
    dose = dose_match ? dose_match[1].to_i : 1

    pattern = {
      morning: 0,
      afternoon: 0,
      evening: 0,
      night: 0
    }

    if times.present?
      if times.is_a?(Hash)
        # times is already a dose_map hash
        times.each do |key, value|
          sym_key = key.to_sym
          if pattern.key?(sym_key)
            pattern[sym_key] = value
          end
        end
      else
        # times is an array of time strings
        times.each do |t|
          key = t.to_sym
          if pattern.key?(key)
            pattern[key] = dose
          end
        end
      end
    else
      # backward compatibility
      case normalized
      when /once a day|od/
        pattern[:morning] = dose
      when /twice a day|bd/
        pattern[:morning] = dose
        pattern[:evening] = dose
      when /three times a day|tds/
        pattern[:morning] = dose
        pattern[:afternoon] = dose
        pattern[:evening] = dose
      when /four times a day|qid/
        pattern.each_key { |k| pattern[k] = dose }
      end
    end

    result = "#{pattern[:morning]} - #{pattern[:afternoon]} - #{pattern[:evening]} - #{pattern[:night]}"
    result
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

    # label width in dots
    label_width = 801
    label = ZebraPrinter::Label.new(label_width, 329, '026', false)

    # font setup
    label.font_size = 2
    label.font_horizontal_multiplier = 2
    label.font_vertical_multiplier = 2

    # barcode position
    barcode_x = 200
    barcode_y = 120
    barcode_height = 120

    # draw barcode
    label.draw_barcode(barcode_x, barcode_y, 0, 1, 5, 15, barcode_height, false, "#{location.location_id}")

    # text setup
    text = location.name.to_s.strip
    font_unit = label.font_size * label.font_horizontal_multiplier * 6
    text_px_est = text.length * font_unit

    # calculate barcode center and align text with it
    barcode_center_x = barcode_x + (400 / 2) # adjust 400 based on your barcode width visually
    x_center = barcode_center_x - (text_px_est / 2)
    x_center = 10 if x_center < 10

    # text above the barcode
    text_y = barcode_y - 60  # move up (adjust for spacing)
    text_y = 10 if text_y < 10

    # draw text centered above barcode
    label.draw_text(
      text,
      x_center.to_i,
      text_y,
      0,
      label.font_size,
      label.font_horizontal_multiplier,
      label.font_vertical_multiplier,
      false
    )

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
