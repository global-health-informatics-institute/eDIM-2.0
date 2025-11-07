class DispensationController < ApplicationController
  def create
    @patient = Patient.find(params[:patient_id]) if params[:patient_id].present?
    return_path = params[:patient_id].present? ? "/patients/#{@patient.id}" : "/"

    # Find stock for current location (could be backstore or dispensary)
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

    begin
      GeneralInventory.transaction do
        # Determine requested quantities
        is_a_bottle = Misc.bottle_item(params[:administration].to_s, item.dose_form.to_s)
        qty_per_pack = is_a_bottle ? 1 : params[:quantity].to_i
        num_packs   = params[:numPacks].to_i
        total_qty   = qty_per_pack * num_packs

        # Use total quantity if prepacking, else just qty_per_pack
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

        # Determine if prescription should be created
        with_prescription =
          params[:prepacking] == 'true' ||
          params[:prescription_mode].to_s == 'with_prescription' ||
          (params[:administration].present? && params[:frequency].present? && params[:doseType].present?)

        rx_id = nil
        directions = nil

        if with_prescription
          directions = Misc.create_directions(
            params[:dose].to_s,
            params[:administration].to_s,
            params[:frequency].to_s,
            params[:doseType].to_s
          )

          @new_prescription = Prescription.create!(
            patient_id:       @patient&.id,
            drug_id:          item.drug_id,
            directions:       directions,
            quantity:         qty_per_pack,
            amount_dispensed: amount_dispensed,
            provider_id:      User.current.id,
            date_prescribed:  Time.current
          )
          rx_id = @new_prescription.id
        end

        # Record dispensation (local to this location)
        @dispensation = Dispensation.create!(
          rx_id:             rx_id,
          inventory_id:      item.gn_inventory_id,
          patient_id:        @patient&.id,
          quantity:          amount_dispensed,
          dispensation_date: Time.current,
          dispensed_by:      User.current.id
        )

        # Record prepack if applicable
        if ActiveModel::Type::Boolean.new.cast(params[:prepacking])
          Prepack.create!(
            bottle_id:        item.gn_inventory_id,
            gn_identifier:    item.gn_identifier,
            drug_id:          item.drug_id,
            quantity_per_pack: qty_per_pack,
            num_packs:        num_packs,
            total_quantity:   total_qty,
            directions:       directions,
            prepacked_by_id:  User.current.id
          )
        end

        dispense_success = true
      end
    rescue => e
      Rails.logger.error "Dispensation failed: #{e.message}"
      flash[:errors] = 'Could not create the dispensation'
    end

    Rails.logger.info "Prepacking param: #{params[:prepacking].inspect}"

    if dispense_success
      if ActiveModel::Type::Boolean.new.cast(params[:prepacking])
        flash[:success] = 'Prepacking labels created successfully'
        print_and_redirect("/print_dispensation_label/#{@new_prescription.id}", return_path)

      elsif @new_prescription.present?
        if @new_prescription.quantity.to_i <= @new_prescription.amount_dispensed.to_i
          print_and_redirect("/print_dispensation_label/#{@new_prescription.id}", return_path)
        else
          flash[:notice] = 'Insufficient quantity. Top up from another bottle'
          redirect_to "/prescriptions/#{@new_prescription.id}"
        end

      else
        flash[:success] = 'Dispensed without prescriptions'
        print_and_redirect("/print_dispensation_label/#{@dispensation.id}", return_path)
      end
    else
      redirect_to return_path
    end
  end

  def refill
    #Function to fill a prescription
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

  def print_dispensation_label
    if Prescription.exists?(params[:id])
      @prescription = Prescription.find(params[:id])
      date = l(@prescription.date_prescribed, format: '%d %B %Y')

      # Check if there is a prepack record for this prescription
      prepack = Prepack.find_by(drug_id: @prescription.drug_id, total_quantity: @prescription.amount_dispensed)

      if prepack.present?
        # Print one label per pack
        print_string = ""
        prepack.num_packs.times do
          print_string += Misc.create_dispensation_label(
            @prescription.drug_name,
            prepack.quantity_per_pack,
            prepack.directions,
            @prescription.patient_name,
            date,
            pack_index: nil,
            total_packs: nil,
            bottle_id: prepack.gn_identifier
          )
        end
      else
        # Regular prescription label
        print_string = Misc.create_dispensation_label(
          @prescription.drug_name,
          @prescription.amount_dispensed,
          @prescription.directions,
          @prescription.patient_name,
          date,
          pack_index: nil,
          total_packs: nil,
          bottle_id: "UNKNOWN" # fallback if no prepack
        )
      end

    elsif Dispensation.exists?(params[:id])
      @dispensation = Dispensation.find(params[:id])
      date = l(@dispensation.dispensation_date, format: '%d %B %Y')

      drug_name = @dispensation.drug_name
      directions = @dispensation.dispensation_dir
      patient_name = @dispensation.patient&.full_name || "Unknown Patient"

      # Check if there is a prepack record for this dispensation
      prepack = Prepack.find_by(drug_id: @dispensation.drug_id, total_quantity: @dispensation.quantity)

      if prepack.present?
        print_string = ""
        prepack.num_packs.times do
          print_string += Misc.create_dispensation_label(
            drug_name,
            prepack.quantity_per_pack,
            prepack.directions,
            patient_name,
            date,
            pack_index: nil,
            total_packs: nil,
            bottle_id: prepack.gn_identifier
          )
        end
      else
        print_string = Misc.create_dispensation_label(
          drug_name,
          @dispensation.quantity,
          directions,
          patient_name,
          date,
          pack_index: nil,
          total_packs: nil,
          bottle_id: "UNKNOWN" # fallback
        )
      end

    else
      render plain: "Invalid label request", status: :not_found and return
    end

    send_data(print_string,
              type: "application/label; charset=utf-8",
              stream: false,
              filename: "#{('a'..'z').to_a.shuffle[0,8].join}.lbl",
              disposition: "inline")
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
      @report_type = "Dispensation Report from #{l(start_date, format: '%d %B, %Y')} #{t('menu.terms.to')} #{l(end_date, format: '%d %B, %Y')}"

    when t('forms.options.monthly')
      start_date = params[:start_date].to_date.beginning_of_month.beginning_of_day
      end_date   = params[:start_date].to_date.end_of_month.end_of_day
      @report_type = "Dispensation Report for #{l(params[:start_date].to_date, format: '%B %Y')}"

    when t('forms.options.range')
      start_date = params[:start_date].to_date.beginning_of_day
      end_date   = params[:end_date].to_date.end_of_day
      @report_type = "Dispensation Report from #{l(start_date, format: '%d %B, %Y')} #{t('menu.terms.to')} #{l(end_date, format: '%d %B, %Y')}"
      
    else
      # default: today
      start_date = Date.today.beginning_of_day
      end_date   = Date.today.end_of_day
      @report_type = "Dispensation Report for #{l(Date.today, format: '%d %B, %Y')}"
    end

    # Fetch dispensations for date range and location
    # Using associations instead of joins
    @records = Dispensation
             .where(dispensation_date: start_date..end_date, voided: false)
             #.where(patient_id: Patient.where(location_id: session[:location]).select(:patient_id))
             .order(dispensation_date: :desc)

    # Render the list
    render :list, layout: 'touch'
  end

  def select
    # In dispensary: always just show the current location
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
