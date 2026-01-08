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
    
    item = GeneralInventory.where(
      gn_identifier: params[:bottle_id],
      location_id: session[:location]
    ).lock(true).first

    if item.blank?
      flash[:errors] = "Bottle ID #{params[:bottle_id]} not found in general inventory for this location"
      redirect_to return_path and return
    end

    dispense_success = false
    @new_prescription = nil
    @prepack_batch = nil

    begin
      GeneralInventory.transaction do
        # Determine requested quantities
        is_a_bottle = Misc.bottle_item(params[:administration].to_s, item.dose_form.to_s)
        qty_per_pack = is_a_bottle ? 1 : params[:quantity].to_i
        num_packs   = params[:numPacks].to_i
        total_qty   = qty_per_pack * num_packs

        amount_dispensed = if ActiveModel::Type::Boolean.new.cast(params[:prepacking])
                            [item.current_quantity.to_i, total_qty].min
                          else
                            [item.current_quantity.to_i, qty_per_pack].min
                          end

        if amount_dispensed <= 0
          flash[:errors] = "Insufficient stock in this location"
          redirect_to return_path and return
        end

        # Decrement current location stock
        item.update!(current_quantity: item.current_quantity - amount_dispensed)

        if ActiveModel::Type::Boolean.new.cast(params[:prepacking])
          # PREPACKING: Create prepack and labels
          directions = Misc.create_directions(
            params[:dose].to_s,
            params[:administration].to_s,
            params[:frequency].to_s,
            params[:doseType].to_s
          )

          @prepack_batch = Prepack.create!(
            bottle_id:        item.gn_inventory_id,
            gn_identifier:    item.gn_identifier,
            drug_id:          item.drug_id,
            quantity_per_pack: qty_per_pack,
            num_packs:        num_packs,
            total_quantity:   total_qty,
            directions:       directions,
            prepacked_by_id:  User.current.id,
            pack_identifier:  SecureRandom.uuid,
            location_id:      session[:location],
            current_num_packs: num_packs
          )

          last_label = PrepackLabel
            .where("label_identifier LIKE ?", "PK-#{item.gn_identifier}-%")
            .order(Arel.sql("CAST(SUBSTRING_INDEX(label_identifier, '-', -1) AS UNSIGNED) DESC"))
            .first

          last_index = last_label ? last_label.label_identifier.split('-').last.to_i : 0

          (1..num_packs).each do |i|
            PrepackLabel.create!(
              prepack_id:      @prepack_batch.id,
              bottle_id:       @prepack_batch.bottle_id,
              label_identifier: "PK-#{item.gn_identifier}-#{last_index + i}"
            )
          end

          dispense_success = true
        else
          # DISPENSING: Create prescription and dispensation
          directions = Misc.create_directions(
            params[:dose].to_s,
            params[:administration].to_s,
            params[:frequency].to_s,
            params[:doseType].to_s
          )

          @new_prescription = Prescription.create!(
            patient_id:       @patient&.id || session[:patient_id],
            drug_id:          item.drug_id,
            directions:       directions,
            quantity:         qty_per_pack,
            amount_dispensed: amount_dispensed,
            provider_id:      User.current.id,
            date_prescribed:  Time.current
          )

          # Record dispensation linked to prescription
          @dispensation = Dispensation.create!(
            rx_id:             @new_prescription.id,
            inventory_id:      item.gn_inventory_id,
            patient_id:        @patient&.id || session[:patient_id],  
            quantity:          amount_dispensed,
            dispensation_date: Time.current,
            dispensed_by:      User.current.id
          )

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
        if @new_prescription.quantity.to_i <= @new_prescription.amount_dispensed.to_i
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

    single = params[:single].to_s == "1"

    find_bottle_by_possible_ids = lambda do |maybe_gn_id|
      GeneralInventory.find_by(gn_inventory_id: maybe_gn_id) ||
        GeneralInventory.find_by(id: maybe_gn_id)
    end

    normalize_expiration = lambda do |exp|
      return nil if exp.blank?
      return exp if exp.is_a?(Date) || exp.is_a?(Time)
      begin
        Date.parse(exp.to_s)
      rescue
        nil
      end
    end

    #  PREPACK BATCH PRINTING
    if params[:id].to_s.start_with?("PREPACK-")
      prepack_id = params[:id].gsub("PREPACK-", "")
      prepack = Prepack.find_by(id: prepack_id)

      unless prepack
        render plain: "Prepack batch not found", status: :not_found and return
      end

      bottle = find_bottle_by_possible_ids.call(prepack.bottle_id)
      expiration_date = normalize_expiration.call(bottle&.expiration_date)
      date = prepack.created_at

      labels = PrepackLabel.where(prepack_id: prepack.id).order(:id)

      if single
        # Print ONLY the first label
        label_record = labels.first
        print_string = Misc.create_dispensation_label(
          prepack.drug.name,
          prepack.quantity_per_pack,
          prepack.directions,
          "",
          date,
          pack_id: label_record.label_identifier,
          pack_index: nil,
          total_packs: nil,
          bottle_id: prepack.gn_identifier,
          expiration_date: expiration_date
        )
      else
        # Default behavior print ALL labels
        labels.each_with_index do |label_record, index|
          print_string += Misc.create_dispensation_label(
            prepack.drug.name,
            prepack.quantity_per_pack,
            prepack.directions,
            "",
            date,
            pack_id: label_record.label_identifier,
            pack_index: index + 1,
            total_packs: labels.size,
            bottle_id: prepack.gn_identifier,
            expiration_date: expiration_date
          )
        end
      end

    # PRESCRIPTION prepack-created batch
    elsif Prescription.exists?(params[:id])
      @prescription = Prescription.find(params[:id])
      date = @prescription.date_prescribed

      prepack = Prepack.where(drug_id: @prescription.drug_id)
                      .where('created_at BETWEEN ? AND ?', 
                            @prescription.created_at - 5.seconds, 
                            @prescription.created_at + 5.seconds)
                      .first

      if prepack
        bottle = find_bottle_by_possible_ids.call(prepack.bottle_id)
        expiration_date = normalize_expiration.call(bottle&.expiration_date)
        labels = PrepackLabel.where(prepack_id: prepack.id).order(:id)

        if single
          # Print ONLY the first label
          label_record = labels.first
          print_string = Misc.create_dispensation_label(
            @prescription.drug_name,
            prepack.quantity_per_pack,
            prepack.directions,
            "",
            date,
            pack_id: label_record.label_identifier,
            pack_index: nil,
            total_packs: nil,
            bottle_id: prepack.gn_identifier,
            expiration_date: expiration_date
          )
        else
          # Print ALL labels
          labels.each_with_index do |label_record, index|
            print_string += Misc.create_dispensation_label(
              @prescription.drug_name,
              prepack.quantity_per_pack,
              prepack.directions,
              "",
              date,
              pack_id: label_record.label_identifier,
              pack_index: index + 1,
              total_packs: labels.size,
              bottle_id: prepack.gn_identifier,
              expiration_date: expiration_date
            )
          end
        end

      else
        # DIRECT BOTTLE DISPENSATION
        disp = Dispensation.find_by(rx_id: @prescription.rx_id)
        bottle = find_bottle_by_possible_ids.call(disp&.inventory_id)
        expiration_date = normalize_expiration.call(bottle&.expiration_date)

        print_string = Misc.create_dispensation_label(
          @prescription.drug_name,
          @prescription.amount_dispensed,
          @prescription.directions,
          @prescription.patient_name,
          date,
          pack_id: "RX-#{@prescription.id}",
          pack_index: nil,
          total_packs: nil,
          bottle_id: bottle&.gn_identifier || "UNKNOWN",
          expiration_date: expiration_date
        )
      end

    # DIRECT DISPENSATION
    elsif Dispensation.exists?(params[:id])
      @dispensation = Dispensation.find(params[:id])
      date = @dispensation.dispensation_date

      drug_name = @dispensation.drug_name
      directions = @dispensation.dispensation_dir
      patient_name = @dispensation.patient&.full_name || "Unknown Patient"

      prepack_label = PrepackLabel.find_by(label_identifier: @dispensation.inventory_id)

      if prepack_label
        # Scanned PK-label, print that one label only
        prepack = prepack_label.prepack
        bottle = find_bottle_by_possible_ids.call(prepack.bottle_id)
        expiration_date = normalize_expiration.call(bottle&.expiration_date)

        print_string = Misc.create_dispensation_label(
          drug_name,
          prepack.quantity_per_pack,
          prepack.directions,
          patient_name,
          date,
          pack_id: prepack_label.label_identifier,
          pack_index: nil,
          total_packs: nil,
          bottle_id: prepack.gn_identifier,
          expiration_date: expiration_date
        )
      else
        # DIRECT bottle dispensation
        inventory = find_bottle_by_possible_ids.call(@dispensation.inventory_id)
        expiration_date = normalize_expiration.call(inventory&.expiration_date)

        print_string = Misc.create_dispensation_label(
          drug_name,
          @dispensation.quantity,
          directions,
          patient_name,
          date,
          pack_id: inventory&.gn_identifier || "DISP-#{@dispensation.id}",
          pack_index: nil,
          total_packs: nil,
          bottle_id: inventory&.gn_identifier || "UNKNOWN",
          expiration_date: expiration_date
        )
      end

    else
      render plain: "Invalid label request", status: :not_found and return
    end

    send_data(
      print_string,
      type: "application/label; charset=utf-8",
      stream: false,
      filename: "#{('a'..'z').to_a.shuffle[0,8].join}.lbl",
      disposition: "inline"
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
      start_date = params[:start_date].to_date.beginning_of_month.beginning_of_day
      end_date   = params[:start_date].to_date.end_of_month.end_of_day
      end_date   = [end_date, Time.zone.now.end_of_day].min

      @report_type = "Dispensation Report for #{l(params[:start_date].to_date, format: '%B %Y')}"
      port_type = "Dispensation Report for #{l(params[:start_date].to_date, format: '%B %Y')}"

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

    redirect_to dispensation.patient
  end

  private

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