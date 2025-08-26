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
        # Determine requested quantity
        is_a_bottle = Misc.bottle_item(params[:administration].to_s, item.dose_form.to_s)
        qty_requested = is_a_bottle ? 1 : params[:quantity].to_i
        amount_dispensed = [item.current_quantity.to_i, qty_requested].min

        if amount_dispensed <= 0
          flash[:errors] = "Insufficient stock in this location"
          redirect_to return_path and return
        end

        # Decrement current location stock
        item.update!(current_quantity: item.current_quantity - amount_dispensed)

        # Prescription logic
        with_prescription =
          params[:prescription_mode].to_s == 'with_prescription' ||
          (params[:administration].present? && params[:frequency].present? && params[:doseType].present?)

        rx_id = nil
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
            quantity:         qty_requested,
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

        dispense_success = true
      end
    rescue => e
      Rails.logger.error "Dispensation failed: #{e.message}"
      flash[:errors] = 'Could not create the dispensation'
    end

    if dispense_success
      if @new_prescription.present?
        if @new_prescription.quantity.to_i <= @new_prescription.amount_dispensed.to_i
          print_and_redirect("/print_dispensation_label/#{@new_prescription.id}", return_path)
        else
          flash[:notice] = 'Insufficient quantity. Top up from another bottle'
          redirect_to "/prescriptions/#{@new_prescription.id}"
        end
      else
        flash[:success] = 'Dispensed without prescription'
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
      # Prescription mode
      @prescription = Prescription.find(params[:id])
      date = l(@prescription.date_prescribed, format: '%d %B %Y')
      print_string = Misc.create_dispensation_label(
        @prescription.drug_name,
        @prescription.amount_dispensed,
        @prescription.directions,
        @prescription.patient_name,
        date
      )
    elsif Dispensation.exists?(params[:id])
      # Dispensation-only mode
      @dispensation = Dispensation.find(params[:id])
      date = l(@dispensation.dispensation_date, format: '%d %B %Y')
      
      drug_name = @dispensation.drug_name
      directions = @dispensation.dispensation_dir
      patient_name = @dispensation.patient&.full_name || "Unknown Patient"
      
      print_string = Misc.create_dispensation_label(
        drug_name,
        @dispensation.quantity,
        directions,
        patient_name,
        date
      )
    else
      render plain: "Invalid label request", status: :not_found and return
    end

    send_data(print_string,
              type: "application/label; charset=utf-8",
              stream: false,
              filename: "#{('a'..'z').to_a.shuffle[0,8].join}.lbl",
              disposition: "inline")
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
