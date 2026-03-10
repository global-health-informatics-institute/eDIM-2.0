class DispensationController < ApplicationController
  def create
    @patient = BillingPatient.find(params[:patient_id]) if params[:patient_id].present?
    session[:patient_id] = @patient.id if @patient.present?

    return_path =
      if params[:prepacking] == 'true'
        '/general_inventory/prepack_labels'
      elsif params[:patient_id].present?
        "/patients/#{@patient.id}"
      else
        '/'
      end
    normalized_times =
      case params[:times]
      when Array
        params[:times].reject(&:blank?)
      when String
        params[:times].split(",").map(&:strip).reject(&:blank?)
      else
        []
      end

    normalized_times_json = normalized_times.to_json

    Rails.logger.info "Normalized times: #{normalized_times.inspect}"

    # Check if this scan is from a prepack label
    prepack_label = PrepackLabel.find_by(label_identifier: params[:bottle_id])
    if prepack_label.present?
      prepack = prepack_label.prepack
      if prepack.present?
        # Use item.location_id directlY
        item = GeneralInventory.find_by(gn_inventory_id: prepack.bottle_id)
        if item.blank?
          flash[:errors] = "Parent bottle for #{params[:bottle_id]} not found in inventory"
          redirect_to return_path and return
        end

        # Automatically dispense from prepack
        begin
          GeneralInventory.transaction do
            if item.current_quantity <= 0
              flash[:errors] = "Insufficient stock for prepack bottle #{prepack.gn_identifier}"
              redirect_to return_path and return
            end

            # Decrease stock by one pack worth
            item.update!(current_quantity: item.current_quantity - prepack.quantity_per_pack)

            # Create prescription for prepack dispensation
            directions = prepack.directions.presence || "Take as directed"
            
            prescription = Prescription.create!(
              patient_id:       @patient&.id || session[:patient_id],
              drug_id:          item.drug_id,
              directions:       directions,
              quantity:         prepack.quantity_per_pack,
              amount_dispensed: prepack.quantity_per_pack,
              times: normalized_times_json,
              provider_id:      User.current.id,
              date_prescribed:  Time.current
            )

            # Create dispensation record linked to prescription
            disp = Dispensation.create!(
              rx_id: prescription.id,
              inventory_id: item.gn_inventory_id,
              patient_id: @patient&.id || session[:patient_id],
              quantity: prepack.quantity_per_pack,
              dispensation_date: Time.current,
              dispensed_by: User.current.id,
              location_id: item.location_id
            )

            flash[:success] = "Successfully dispensed #{item.drug.name} (Prepack #{params[:bottle_id]})"
            print_and_redirect("/print_dispensation_label/#{prescription.id}", return_path)
          end
        rescue => e
          flash[:errors] = "Could not complete prepack dispensation"
          redirect_to return_path
        end
        return
      end
    end

    # Continue with normal bottle dispensing flow
    if session[:location].blank?
      flash[:errors] = "Location is not set. Please select a location first."
      redirect_to return_path and return
    end
    
    # Find all available bottles for this identifier
    available_items = GeneralInventory.where(
      gn_identifier: params[:bottle_id],
      location_id: session[:location],
      voided: false
    ).where('current_quantity > 0')
    .order(:expiration_date, :gn_inventory_id)
    .lock(true)

    if available_items.empty?
      flash[:errors] = "Bottle ID #{params[:bottle_id]} not found or out of stock in this location"
      redirect_to return_path and return
    end

    dispense_success = false
    @new_prescription = nil
    @prepack_batch = nil
    dispense_result = nil

    begin
      GeneralInventory.transaction do
        # Determine requested quantities
        requested_qty = params[:quantity].to_i

        if requested_qty <= 0
          flash[:errors] = "Invalid quantity"
          redirect_to return_path and return
        end

        qty_per_pack = requested_qty
        num_packs    = params[:numPacks].to_i.presence || 1
        total_qty    = qty_per_pack * num_packs

        # Calculate total available quantity
        total_available = available_items.sum(:current_quantity)

        # For prepacking, we need the full total quantity
        # For regular dispensing, we need just the qty_per_pack
        needed_quantity = if ActiveModel::Type::Boolean.new.cast(params[:prepacking])
                           total_qty
                         else
                           qty_per_pack
                         end

        if needed_quantity > total_available
          flash[:errors] = "Insufficient stock. Requested: #{needed_quantity}, Available: #{total_available}"
          redirect_to return_path and return
        end

        # Dispense from multiple bottles using FIFO
        dispense_result = dispense_from_multiple_bottles(available_items, needed_quantity)
        
        unless dispense_result[:fully_dispensed]
          flash[:errors] = "Insufficient stock to dispense full quantity. Requested: #{needed_quantity}, Available: #{total_available}. Dispensation cancelled."
          redirect_to return_path and return
        end

        # Use the first item for drug info and primary reference
        primary_item = dispense_result[:dispensed_items].first[:item]

        if ActiveModel::Type::Boolean.new.cast(params[:prepacking])
          # Prepacking: Create prepack and labels
          directions = Misc.create_directions(
            params[:dose].to_s,
            params[:administration].to_s,
            params[:frequency].to_s,
            params[:doseType].to_s
          )

          @prepack_batch = Prepack.create!(
            bottle_id:        primary_item.gn_inventory_id,
            gn_identifier:    primary_item.gn_identifier,
            drug_id:          primary_item.drug_id,
            quantity_per_pack: qty_per_pack,
            num_packs:        num_packs,
            total_quantity:   total_qty,
            directions:       directions,
            times: normalized_times.to_json,
            prepacked_by_id:  User.current.id,
            pack_identifier:  SecureRandom.uuid,
            location_id:      session[:location],
            current_num_packs: num_packs
          )

          last_label = PrepackLabel
            .where("label_identifier LIKE ?", "PK-#{primary_item.gn_identifier}-%")
            .order(Arel.sql("CAST(SUBSTRING_INDEX(label_identifier, '-', -1) AS UNSIGNED) DESC"))
            .first

          last_index = last_label ? last_label.label_identifier.split('-').last.to_i : 0

          (1..num_packs).each do |i|
            PrepackLabel.create!(
              prepack_id:      @prepack_batch.id,
              bottle_id:       @prepack_batch.bottle_id,
              label_identifier: "PK-#{primary_item.gn_identifier}-#{last_index + i}"
            )
          end

          dispense_success = true
        else
          # DISPENSING: Create prescription and dispensation records
          directions = Misc.create_directions(
            params[:dose].to_s,
            params[:administration].to_s,
            params[:frequency].to_s,
            params[:doseType].to_s
          )

          @new_prescription = Prescription.create!(
            patient_id:       @patient&.id || session[:patient_id],
            drug_id:          primary_item.drug_id,
            directions:       directions,
            times:            normalized_times_json,
            quantity:         qty_per_pack,
            amount_dispensed: dispense_result[:total_dispensed],
            provider_id:      User.current.id,
            date_prescribed:  Time.current
          )

          # Create dispensation records for each bottle used
          dispense_result[:dispensed_items].each do |dispensed_item|
            Dispensation.create!(
              rx_id:             @new_prescription.id,
              inventory_id:      dispensed_item[:item].gn_inventory_id,
              patient_id:        @patient&.id || session[:patient_id],
              quantity:          dispensed_item[:quantity],
              dispensation_date: Time.current,
              dispensed_by:      User.current.id
            )
          end

          dispense_success = true
        end
      end
    rescue => e
      Rails.logger.error "Dispensation failed: #{e.message}"
      flash[:errors] = 'Could not create the dispensation'
    end

    Rails.logger.info "Prepacking param: #{params[:prepacking].inspect}"

    if dispense_success
      if ActiveModel::Type::Boolean.new.cast(params[:prepacking])
        flash[:success] = 'Prepacking labels created successfully'
        # Print using the prepack batch ID with special prefix
        print_and_redirect("/print_dispensation_label/PREPACK-#{@prepack_batch.id}", return_path)
      else
        # Check if prescription was fully dispensed
        if @new_prescription.quantity.to_i <= @new_prescription.amount_dispensed.to_i
          bottles_used = dispense_result&.dig(:dispensed_items)&.size || 1
          if bottles_used > 1
            flash[:success] = "Successfully dispensed #{@new_prescription.amount_dispensed} units from #{bottles_used} bottles"
          end
          print_and_redirect("/print_dispensation_label/#{@new_prescription.id}", return_path)
        else
          flash[:notice] = 'Insufficient quantity. Top up from another bottle'
          redirect_to "/prescriptions/#{@new_prescription.id}"
        end
      end
    else
      redirect_to return_path
    end
  end

  def print_dispensation_label
    print_string = ""

    slots = %w[morning afternoon evening night]

    build_dose_map = lambda do |directions, raw_times|
      times =
        case raw_times
        when String then JSON.parse(raw_times)
        when Array  then raw_times
        else []
        end

      times = times.map(&:strip).map(&:downcase)

      dose = directions.to_s[/Take\s+(\d+)/i, 1].to_i
      dose = 1 if dose <= 0

      slots.each_with_object({}) do |slot, h|
        h[slot.to_sym] = times.include?(slot) ? dose : 0
      end
    end

    find_bottle = lambda do |id|
      GeneralInventory.find_by(gn_inventory_id: id) ||
        GeneralInventory.find_by(id: id)
    end

    normalize_expiration = lambda do |exp|
      return nil if exp.blank?
      return exp if exp.is_a?(Date) || exp.is_a?(Time)
      Date.parse(exp.to_s) rescue nil
    end

    single = params[:single].to_s == "1"
    print_all_undispensed = params[:print_all_undispensed].to_s == "1"
    print_lowest_undispensed = params[:print_lowest_undispensed].to_s == "1"

    # Prepacking drugs
    if params[:id].to_s.start_with?("PREPACK-")
      prepack_id = params[:id].delete_prefix("PREPACK-").to_i
      
      # Check if prepack_id is valid
      if prepack_id.nil? || prepack_id == 0
        return render plain: "Invalid prepack ID", status: :bad_request
      end
      
      prepack = Prepack.find_by(id: prepack_id)
      return render plain: "Prepack batch not found", status: :not_found unless prepack

      dose_map = build_dose_map.call(prepack.directions, prepack.times)

      bottle = find_bottle.call(prepack.bottle_id)
      expiration_date = normalize_expiration.call(bottle&.expiration_date)

      labels = PrepackLabel.where(prepack_id: prepack.id).order(:id)
      
      # Handle different print options
      if print_all_undispensed
        # Print all undispensed labels (not deleted AND not dispensed)
        # deleted = 0 means not deleted, dispensed = 0 means not dispensed
        labels = labels.where(deleted: 0, dispensed: 0)
      elsif print_lowest_undispensed
        # Print only the lowest undispensed label
        labels = labels.where(dispensed: [false, nil]).order(:id).limit(1)
        if labels.empty?
          return render plain: "No undispensed labels found", status: :not_found
        end
      elsif single
        labels = labels.first(1)
      end

      labels.each_with_index do |label, index|
        print_string += Misc.create_dispensation_label(
          prepack.drug.name,
          prepack.quantity_per_pack,
          prepack.directions,
          "",
          prepack.created_at,
          times: dose_map,
          pack_id: label.label_identifier,
          pack_index: (print_all_undispensed || print_lowest_undispensed || single) ? nil : index + 1,
          total_packs: print_all_undispensed ? nil : labels.size,
          bottle_id: prepack.gn_identifier,
          expiration_date: expiration_date
        )
      end

    # Prescription-based dispensations
    elsif Prescription.exists?(params[:id])
      rx = Prescription.find(params[:id])
      dose_map = build_dose_map.call(rx.directions, rx.times)

      disp = Dispensation.find_by(rx_id: rx.id)
      bottle = find_bottle.call(disp&.inventory_id)
      expiration_date = normalize_expiration.call(bottle&.expiration_date)

      print_string = Misc.create_dispensation_label(
        rx.drug_name,
        rx.amount_dispensed,
        rx.directions,
        rx.patient_name,
        rx.date_prescribed,
        times: dose_map,
        pack_id: "RX-#{rx.id}",
        bottle_id: bottle&.gn_identifier || "UNKNOWN",
        expiration_date: expiration_date
      )

    # Direct dispensation 
    elsif Dispensation.exists?(params[:id])
      disp = Dispensation.find(params[:id])
      dose_map = build_dose_map.call(disp.dispensation_dir, [])

      bottle = find_bottle.call(disp.inventory_id)
      expiration_date = normalize_expiration.call(bottle&.expiration_date)

      print_string = Misc.create_dispensation_label(
        disp.drug_name,
        disp.quantity,
        disp.dispensation_dir,
        disp.patient&.full_name || "Unknown Patient",
        disp.dispensation_date,
        times: dose_map,
        pack_id: bottle&.gn_identifier || "DISP-#{disp.id}",
        bottle_id: bottle&.gn_identifier || "UNKNOWN",
        expiration_date: expiration_date
      )

    else
      return render plain: "Invalid label request", status: :not_found
    end

    send_data(
      print_string,
      type: "application/label; charset=utf-8",
      disposition: "inline",
      filename: "#{('a'..'z').to_a.sample(8).join}.lbl"
    )
  end

  def search_and_print_label
    print_string = ""

    slots = %w[morning afternoon evening night]

    build_dose_map = lambda do |directions, raw_times|
      times =
        case raw_times
        when String then JSON.parse(raw_times)
        when Array  then raw_times
        else []
        end

      times = times.map(&:strip).map(&:downcase)

      dose = directions.to_s[/Take\s+(\d+)/i, 1].to_i
      dose = 1 if dose <= 0

      slots.each_with_object({}) do |slot, h|
        h[slot.to_sym] = times.include?(slot) ? dose : 0
      end
    end

    normalize_expiration = lambda do |exp|
      return nil if exp.blank?
      return exp if exp.is_a?(Date) || exp.is_a?(Time)
      Date.parse(exp.to_s) rescue nil
    end

    # Search for label by label_identifier (e.g., PK-G0000059-2-001)
    label_identifier = params[:label_identifier].to_s.strip
    
    return render plain: "Label identifier is required", status: :bad_request if label_identifier.blank?

    # Debug: log what's being searched
    Rails.logger.debug "Searching for label: #{label_identifier}"
    
    # Try to find the label by label_identifier (deleted = 0, dispensed = 0 for available)
    label = PrepackLabel.where(deleted: 0, dispensed: 0).find_by(label_identifier: label_identifier)
    
    Rails.logger.debug "Exact match result: #{label.inspect}"
    
    # If not found, try to find by partial match (starts with)
    if label.nil?
      label = PrepackLabel.where(deleted: 0, dispensed: 0).where("label_identifier LIKE ?", "#{label_identifier}%").first
      Rails.logger.debug "LIKE match result: #{label.inspect}"
    end
    
    if label.nil?
      # Try without deleted/undispensed filter
      label = PrepackLabel.find_by(label_identifier: label_identifier)
      Rails.logger.debug "No filter match result: #{label.inspect}"
      
      if label.nil?
        return render plain: "Label not found: #{label_identifier}", status: :not_found
      end
      
      # Check if label exists but is deleted
      if label.deleted == 1
        return render plain: "Label is deleted: #{label_identifier}", status: :not_found
      end
      
      # Check if label is already dispensed
      if label.dispensed == 1
        return render plain: "Label already dispensed: #{label_identifier}", status: :conflict
      end
    end

    # Get the prepack batch
    prepack = label.prepack
    return render plain: "Prepack batch not found for this label", status: :not_found unless prepack

    dose_map = build_dose_map.call(prepack.directions, prepack.times)

    bottle = prepack.bottle
    expiration_date = normalize_expiration.call(bottle&.expiration_date)

    print_string = Misc.create_dispensation_label(
      prepack.drug.name,
      prepack.quantity_per_pack,
      prepack.directions,
      "",
      prepack.created_at,
      times: dose_map,
      pack_id: label.label_identifier,
      pack_index: nil,
      total_packs: nil,
      bottle_id: prepack.gn_identifier,
      expiration_date: expiration_date
    )

    send_data(
      print_string,
      type: "application/label; charset=utf-8",
      disposition: "inline",
      filename: "#{('a'..'z').to_a.sample(8).join}.lbl"
    )
  end

  def refill
    # Function to fill a prescription
    GeneralInventory.transaction do
      item = GeneralInventory.where("gn_identifier = ? ", params[:bottle_id]).lock(true).first
      qty = params[:quantity].to_i
      amount_dispensed = ((item.current_quantity.to_i - qty) >= -1 ? qty : item.current_quantity.to_i)
      item.current_quantity -= amount_dispensed
      item.save

      return_path = (params[:patient_id].blank? ? '/' : "/patients/#{params[:patient_id]}")

      if item.errors.blank?
        @prescription = Prescription.find(params[:prescription])
        @prescription.amount_dispensed = @prescription.amount_dispensed.to_i + amount_dispensed.to_i
        @prescription.save!


        @dispensation = Dispensation.create({:rx_id => @prescription.id, :inventory_id => item.bottle_id,
                                             :patient_id => @prescription.patient_id, :quantity => amount_dispensed,
                                             :dispensation_date => Time.current, :dispensed_by => User.current.id})

        if @dispensation.errors.blank?
          if @prescription.quantity <= @prescription.amount_dispensed
            print_and_redirect("/print_dispensation_label/#{@prescription.id}", return_path) and return
          else
            flash[:notice] = 'Insufficient quantity. Top up from another bottle'
            redirect_to "/prescriptions/#{@prescription.id}" and return
          end
        end
      else
        flash[:errors] = 'Could not create the dispensation'
      end
    end
    redirect_to (return_path || "/") and return
  end

  def list
    # Determine date range and report type
    case params[:report_duration]
    when t('forms.options.daily')
      start_date = params[:start_date].to_date.beginning_of_day
      end_date   = params[:start_date].to_date.end_of_day
      @report_type = "Dispensation Report for #{l(start_date, format: '%d %B, %Y')}"

    when t('forms.options.weekly')
      start_date = params[:start_date].to_date.beginning_of_day
      end_date   = (start_date + 6.days).end_of_day
      end_date   = [end_date, Time.zone.now.end_of_day].min

      @report_type = "Dispensation Report from #{l(start_date, format: '%d %B, %Y')} #{t('menu.terms.to')} #{l(end_date, format: '%d %B, %Y')}"

    when t('forms.options.monthly')
      start_date = params[:start_date].to_date.beginning_of_day
      end_date   = (params[:start_date].to_date + 1.month - 1.day).end_of_day
      end_date   = [end_date, Time.zone.now.end_of_day].min

      @report_type = "Dispensation Report from #{l(start_date, format: '%d %B, %Y')} #{t('menu.terms.to')} #{l(end_date, format: '%d %B, %Y')}"
      port_type = @report_type

    when t('forms.options.range')
      start_date = params[:start_date].to_date.beginning_of_day
      end_date   = params[:end_date].to_date.end_of_day
      @report_type = "Dispensation Report from #{l(start_date, format: '%d %B, %Y')} #{t('menu.terms.to')} #{l(end_date, format: '%d %B, %Y')}"
      
    else
      # default to today
      start_date = Date.today.beginning_of_day
      end_date   = Date.today.end_of_day
      @report_type = "Dispensation Report for #{l(Date.today, format: '%d %B, %Y')}"
    end

    # Fetch dispensations for date range and location
    @records = Dispensation
             .where(dispensation_date: start_date..end_date, voided: false)
             #.where(patient_id: Patient.where(location_id: session[:location]).select(:patient_id))
             .order(dispensation_date: :desc)

    # Render the list
    render :list, layout: 'touch'
  end

  def select
    # Select report type
    @locations = [Location.find(session[:location])&.name].compact
    render layout: 'touch'
  end

  def destroy
    #Delete an dispensation
    dispensation = Dispensation.void(params[:id])

    if dispensation.voided
      flash[:success] = "Dispensation successfully voided"
    else
      flash[:errors] = "Failed to void the dispensation"
    end

    #rails show route
     redirect_to patient_path(dispensation.patient)  
 

  end

  private

  # Multi-bottle FIFO dispensing method
  def dispense_from_multiple_bottles(available_items, requested_quantity)
    # First, do a dry run to check if we have enough stock
    total_available = available_items.sum(:current_quantity)
    
    if requested_quantity > total_available
      return {
        dispensed_items: [],
        total_dispensed: 0,
        fully_dispensed: false,
        available: total_available
      }
    end

    # If we have enough stock, proceed with actual dispensing
    dispensed_items = []
    remaining_to_dispense = requested_quantity
    total_dispensed = 0

    available_items.each do |item|
      break if remaining_to_dispense <= 0

      # Calculate how much to take from this bottle
      quantity_from_this_bottle = [item.current_quantity, remaining_to_dispense].min
      
      if quantity_from_this_bottle > 0
        # Update the bottle quantity
        item.update!(current_quantity: item.current_quantity - quantity_from_this_bottle)
        
        # Track what we dispensed
        dispensed_items << {
          item: item,
          quantity: quantity_from_this_bottle
        }
        
        total_dispensed += quantity_from_this_bottle
        remaining_to_dispense -= quantity_from_this_bottle
      end
    end

    {
      dispensed_items: dispensed_items,
      total_dispensed: total_dispensed,
      fully_dispensed: remaining_to_dispense <= 0,
      available: total_available
    }
  end

  def dispense_item(inventory,prescription,dispense_amount)

    Dispensation.transaction do

      inventory.current_quantity -= dispense_amount.to_i

      if inventory.save

      prescription.amount_dispensed = prescription.amount_dispensed.to_i + dispense_amount.to_i
      prescription.save!  

        dispensation = Dispensation.create({:rx_id => prescription.id, :inventory_id => inventory.bottle_id,
                                            :patient_id => prescription.patient_id, :quantity => dispense_amount,
                                            :dispensation_date => Time.now})

        logger.info "#{current_user.username} dispensed #{dispense_amount} of #{inventory.bottle_id} (RX:#{prescription.id})"
      else
        return false
      end
    end
  end
end
