class GeneralInventoryController < ApplicationController

  def index
    location_id = session[:location]

    @inventory = GeneralInventory
                  .where(voided: false, location_id: location_id)
                  .joins(:drug => :drug_category)       # eager load
                  .select('general_inventories.*, drugs.name AS drug_name, drug_categories.category AS drug_category_name')
                  .group('general_inventories.drug_id')
                  .having('SUM(general_inventories.current_quantity) > 0')
  end

  def edit
    if request.post?
      # Edit a new record for general inventory
      @new_stock_entry = GeneralInventory.find_by_gn_identifier(params[:bottle_id])

      if @new_stock_entry.blank?
        flash[:errors] = "Item could not be found"
      else
        @new_stock_entry.expiration_date = params[:expiry_date].to_date rescue nil
        @new_stock_entry.received_quantity = params[:amount_received].to_i + (@new_stock_entry.received_quantity - @new_stock_entry.current_quantity)
        @new_stock_entry.current_quantity = params[:amount_received].to_i
        @new_stock_entry.location_id = session[:location]

        GeneralInventory.transaction do
          @new_stock_entry.save
        end

        if @new_stock_entry.errors.blank?
          flash[:success] = "#{@new_stock_entry.drug_name} (Bottle #: #{@new_stock_entry.gn_identifier}) was successfully updated."
        else
          flash[:errors] = @new_stock_entry.errors
        end
      end

      redirect_to "/" and return

    else
      dispensary_loc = Location.find_by_name("Dispensary")&.id
      @is_dispensary = session[:location] == dispensary_loc
      render :layout => "touch"
    end
  end

  def new
    dispensary_loc = Location.find_by_name("Dispensary")&.id
    @is_dispensary = session[:location] == dispensary_loc
    backstore_location = Location.find_by_name("Backstore")&.id || 5

    # detect if this is "Add Drug" from dispensary menu
    @dispensary_add_mode = params[:add_mode] == "true"

    if @is_dispensary && !@dispensary_add_mode
      # DISPENSARY normal request flow: only items with stock at Backstore
      @available_categories = GeneralInventory
                                .joins(drug: :drug_category)
                                .where(location_id: backstore_location, voided: false)
                                .where("current_quantity > 0")
                                .distinct
                                .pluck("drug_categories.category")
                                .sort

      if params[:drug_category].present?
        @available_drugs = GeneralInventory
                              .joins(drug: :drug_category)
                              .where(location_id: backstore_location, voided: false)
                              .where("current_quantity > 0")
                              .where("drug_categories.category = ?", params[:drug_category])
                              .distinct
                              .pluck("drugs.name")
                              .sort
      else
        @available_drugs = []
      end
    else
      # BACKSTORE add OR DISPENSARY add: show all categories and all drugs in selected category
      @available_categories = DrugCategory.all.pluck(:category).sort

      if params[:drug_category].present?
        @available_drugs = Drug.joins(:drug_category)
                              .where(drug_categories: { category: params[:drug_category] })
                              .pluck(:name)
                              .sort
      else
        @available_drugs = []
      end
    end

    render layout: "touch"
  end

  def create

    if params[:general_inventory] && params[:general_inventory][:amount_requested].present?
      requested = params[:general_inventory][:amount_requested].to_i
      drug_name = params[:general_inventory][:drug_name].to_s.strip
      category_name = params[:general_inventory][:drug_category].to_s.strip

      # lookup to find drug
      drug = Drug.joins(:drug_category)
                .where("drugs.name = ? AND drug_categories.category = ?", drug_name, category_name)
                .first

      if drug
        backstore_id = Location.find_by_name("Backstore")&.id || 5
        available = GeneralInventory.where(drug_id: drug.id, location_id: backstore_id, voided: false)
                                    .sum(:current_quantity).to_i

        if requested > available
          flash[:errors] = "You cannot request more than #{available} units."
          redirect_to new_general_inventory_path and return
        end
      end
    end

    dispensary_loc = Location.find_by_name("Dispensary")&.id
    is_dispensary = session[:location] == dispensary_loc

    inventory_params = params[:general_inventory] || {}

    drug_name     = inventory_params[:drug_name].to_s.strip
    drug_category = inventory_params[:drug_category].to_s.strip

    # Backstore additions
    drug = Drug.joins(:drug_category)
              .where(
                name: drug_name,
                drug_categories: { category: drug_category }
              )
              .first

    if drug.nil?
      flash[:errors] = "The selected drug could not be found"
      redirect_to("/") and return
    end

    drug_id = drug.drug_id

    count = inventory_params[:number_of_items].to_i rescue 0
    iterations = (0..count).size

    mode = inventory_params[:mode] || 'request'

    if is_dispensary && mode == 'request'
      requested_qty = inventory_params[:amount_requested].to_s.strip.to_i

      if requested_qty <= 0
        flash[:errors] = "Quantity must be greater than 0"
        redirect_to "/" and return
      end

      total_qty = requested_qty * (count > 0 ? count : 1)

      # get oldest inventory entry from backstore to copy gn_identifier
      backstore_id = Location.find_by_name("Backstore")&.id || 5
      inventory_entry = GeneralInventory.where(drug_id: drug.id, location_id: backstore_id, voided: false)
                                        .order(:date_received)
                                        .first

      gn_identifier = inventory_entry&.gn_identifier

      begin
        Request.transaction do
          request = Request.new(
            drug_id:      drug_id,
            location_id:  session[:location],
            quantity:     total_qty,
            fulfilled:    false,
            gn_identifier: gn_identifier
          )

          unless request.save
            raise ActiveRecord::Rollback, request.errors.full_messages.join(", ")
          end
        end

        num_requests = count > 0 ? count : 1
        flash[:success] = "#{num_requests} request(s) for #{drug_name} (total qty: #{total_qty}) submitted successfully."
        redirect_to "/" and return


      rescue => e
        flash[:errors] = "Failed to submit request: #{e.message}"
        redirect_to "/" and return
      end
    end

    # BACKSTORE flow: insert new general inventory entries
    received_qty = inventory_params[:amount_received].to_s.strip.to_i
    if received_qty <= 0
      flash[:errors] = "Quantity must be greater than 0"
      redirect_to "/" and return
    end

    expiry_date = begin
      inventory_params[:expiry_date].to_s.strip.presence&.to_date
    rescue
      nil
    end

    ids = []
    GeneralInventory.transaction do
      (0..count).each do |_i|
        new_stock_entry = GeneralInventory.new(
          drug_id:           drug_id,
          current_quantity:  received_qty,
          received_quantity: received_qty,
          expiration_date:   expiry_date,
          date_received:     Date.current,
          location_id:       session[:location],
        )

        if new_stock_entry.save
          ids << new_stock_entry.id
        else
          flash[:errors] = new_stock_entry.errors.full_messages.join(", ")
          redirect_to "/" and return
        end
      end
    end

    if ids.length > 1
      flash[:success] = "#{ids.length} #{t('messages.items_of')} #{drug_name} #{t('messages.add_items_success')}."
      print_and_redirect("/general_inventory/print_bottle_barcode?ids=#{ids.join(',')}", "/")
    else
      flash[:success] = "#{drug_name} #{t('messages.add_item_success')}."
      print_and_redirect("/print_bottle_barcode/#{ids.first}", "/")
    end
  end

  def destroy
    #Delete an item from general inventory
    item = GeneralInventory.void_item(params[:id])
    if item.blank?
      flash[:errors]= "Item with bottle id #{params[:general_inventory][:gn_id]} could not be found"
    elsif item.errors.blank?
      flash[:success] = "#{item.drug_name} #{item.gn_identifier} was successfully deleted."
=begin
      news = News.where("refers_to = ? AND resolved = ?",
                        params[:general_inventory][:gn_id], false).first
      unless news.blank?
        news.resolved = true
        news.resolution = "Item was voided"
        news.date_resolved= Date.today
        news.save
      end
=end
    else
      flash[:errors] = item.errors
    end

    redirect_to "/general_inventory"
  end

  def print_bottle_barcode
    #This function prints bottle barcode labels for both inventory types
    id = params[:ids].split(',') rescue params[:id]
    entry = GeneralInventory.find(id)
    if entry.is_a?(Array)
      print_string = ""
      (entry || []).each do |bottle|
        print_string += "#{Misc.create_bottle_label(bottle.drug_name,bottle.gn_identifier,bottle.expiration_date)}\n"
      end
    else
      print_string = Misc.create_bottle_label(entry.drug_name,entry.gn_identifier,entry.expiration_date)
    end

    chars = ("a".."z").to_a  + ("0".."9").to_a
    rand_str = ""
    1.upto(7) { |i| rand_str << chars[rand(chars.size-1)] }
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{rand_str}.lbl", :disposition => "inline")
  end
   
  def ajax_bottle
    scanned = params[:id].to_s.strip

    # Determine context
    context = params[:context] || 
              (request.referer&.include?('/prepack_labels') ? 'prepacking' : 'patient')

    # Fix malformed PK codes
    if scanned =~ /\APK(G\d{7}-\d+)\z/i
      scanned = scanned.sub("PKG", "PK-G")
    end

    # Handle Prepack labels
    if scanned.start_with?("PK-")
      # Fetch undispensed label only
      label = PrepackLabel.find_by(label_identifier: scanned, dispensed: 0, voided: 0, deleted: 0)

      if label.nil?
        return render json: { error: "This prepack has already been dispensed or is invalid" }
      end

      prepack = label.prepack

      if context == "patient"
        bottle = GeneralInventory.find_by(
          gn_inventory_id: prepack.bottle_id,
          location_id: session[:location]
        )

        if bottle.nil? || bottle.current_quantity <= 0
          return render json: { error: "Bottle empty for this prepack" }
        end

        # Get patient_id from session or params
        patient_id = params[:patient_id] || session[:patient_id]

        # If patient_id is still nil
        if patient_id.nil?
          return render json: { error: "Patient context missing" }
        end

        disp = nil
        prescription = nil

        GeneralInventory.transaction do
          # Create a prescription record for this prepack dispensing
          prescription = Prescription.create!(
            patient_id: patient_id,
            drug_id: bottle.drug_id,
            date_prescribed: Time.current,
            quantity: prepack.quantity_per_pack,
            amount_dispensed: prepack.quantity_per_pack,
            directions: prepack.directions || "Dispensed as prepack",
            provider_id: User.current.id
          )

          # Record dispensation WITH the newly created prescription_id
          disp = Dispensation.create!(
            rx_id: prescription.id,
            inventory_id: bottle.gn_inventory_id,
            patient_id: patient_id,
            quantity: prepack.quantity_per_pack,
            dispensation_date: Time.current,
            dispensed_by: User.current.id
          )

          label.assign_attributes(
            dispensed: 1,
            patient_id: patient_id,
            dispensed_by: User.current.id,
          )

          label.save!

          if prepack.prepack_labels.where(dispensed: 1).count == prepack.num_packs
            prepack.update!(
              status: 'dispensed',
              dispensed_at: Time.current,
              location_id: prepack.location_id || session[:location]  
            )
          end
        end

        return render json: {
          prepack: true,
          message: "Successfully dispensed #{bottle.drug.name}",
          quantity: prepack.quantity_per_pack,
          dispensation_id: disp.id,
          prescription_id: prescription.id,
          currentQty: bottle.current_quantity
        }
      end

      # Prepacking mode, return info about this pack
      return render json: {
        prepack: true,
        drug_id: prepack.bottle_id,
        quantity_per_pack: prepack.quantity_per_pack,
        label: label.label_identifier
      }
    end

    # Handle regular bottle scan
    entry = GeneralInventory.includes(:drug)
                            .find_by(
                              gn_identifier: scanned,
                              location_id: session[:location],
                              voided: false
                            )

    if entry.nil?
      return render plain: "false"
    end

    # Check if any active prepacks exist for this bottle
    has_active_prepacks = PrepackLabel
                            .where(bottle_id: entry.gn_inventory_id, dispensed: 0)
                            .exists?

    render json: {
      name: entry.drug.name,
      currentQty: entry.current_quantity,
      prepack: has_active_prepacks
    }
  end

  def show
    @item = GeneralInventory.find_by(
      gn_identifier: params[:id].to_s,
      location_id: session[:location]
    )

    if @item.blank?
      flash[:errors] = "Item with ID #{params[:id]} not found in this location"
      redirect_to "/" and return
    end

    # Load all transaction records for this inventory item at this location
    @records = Issue.where(inventory_id: @item.gn_inventory_id).order(issue_date: :desc)

  end

  def list
    @drug = Drug.find_by_drug_id(params[:drug_id])
    @inventory = GeneralInventory.where("current_quantity > ? and drug_id = ? and location_id = ? and voided = ?",
                                        0, params[:drug_id] ,session[:location], false)
  end

  def prepack_labels

    render :prepack_labels
  end

  def pre_packing
    GeneralInventory.transaction do
      @item = GeneralInventory.where("gn_identifier = ? ", params[:bottle_id]).lock(true).first
      @item.current_quantity = @item.current_quantity.to_i - params[:pre_pack_amount].to_i
      @item.received_quantity = @item.received_quantity.to_i - params[:pre_pack_amount].to_i
      @item.save

      if @item.errors.blank?
        @new_stock_entry = GeneralInventory.new
        @new_stock_entry.drug_id = @item.drug_id
        @new_stock_entry.current_quantity = params[:pre_pack_amount]
        @new_stock_entry.expiration_date = @item.expiration_date
        @new_stock_entry.received_quantity = params[:pre_pack_amount]
        @new_stock_entry.date_received = Date.current
        @new_stock_entry.location_id = @item.location_id
        @new_stock_entry.save

        if @new_stock_entry.errors.blank?
          flash[:success] = "#{params[:bottle_id]} was successfully issued."
          print_and_redirect("/general_inventory/print_pre_packed/#{@new_stock_entry.id}", "/general_inventory/#{@item.gn_identifier}")
        else
          flash[:errors] = "Insufficient stock on hand"
          redirect_to "/general_inventory/#{@item.gn_identifier}" and return
        end
      end
    end
  end

  def merge
    bottles = GeneralInventory.where(gn_inventory_id: params[:bottle_ids].split(','))
    quantity = 0
    GeneralInventory.transaction do
      (bottles || []).each do |bottle|
        quantity += bottle.current_quantity.to_i
        bottle.received_quantity = bottle.received_quantity.to_i - bottle.current_quantity.to_i
        bottle.current_quantity = 0
        bottle.save
      end

      item = bottles.first

      @new_stock_entry = GeneralInventory.new
      @new_stock_entry.drug_id = item.drug_id
      @new_stock_entry.current_quantity = quantity
      @new_stock_entry.expiration_date = item.expiration_date
      @new_stock_entry.received_quantity = quantity
      @new_stock_entry.date_received = Date.current
      @new_stock_entry.location_id = item.location_id
      @new_stock_entry.save

      if @new_stock_entry.errors.blank?
        flash[:success] = "Items were successfully merged."
        print_and_redirect("/print_bottle_barcode/#{@new_stock_entry.id}", "/general_inventory/list?drug_id=#{item.drug_id}")
      else
        flash[:errors] = "Items could not be merged"
        redirect_to "/general_inventory/#{@new_stock_entry.gn_identifier}" and return
      end
    end
  end

  def print_pre_packed
    #This function prints bottle barcode labels for both inventory types
    id = params[:ids].split(',') rescue params[:id]
    entry = GeneralInventory.find(id)
    if entry.is_a?(Array)
      print_string = ""
      (entry || []).each do |bottle|
        print_string += "#{Misc.create_bottle_label(bottle.drug_name,bottle.gn_identifier,bottle.expiration_date,bottle.received_quantity)}\n"
      end
    else
      print_string = Misc.create_bottle_label(entry.drug_name,entry.gn_identifier,entry.expiration_date, entry.received_quantity)
    end

    chars = ("a".."z").to_a  + ("0".."9").to_a
    rand_str = ""
    1.upto(7) { |i| rand_str << chars[rand(chars.size-1)] }
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{rand_str}.lbl", :disposition => "inline")
  end

  def damage_item
    # Find prepack
    prepack = Prepack.find_by(
      id: params[:id],
      location_id: session[:location] || User.current.location_id,
      voided: 0,
      deleted: 0
    )

    unless prepack
      render json: { success: false, message: "Prepack not found" }, status: 404 and return
    end

    # Find general inventory record
    item = GeneralInventory.find_by(gn_identifier: prepack.gn_identifier)
    unless item
      render json: { success: false, message: "Inventory item not found" }, status: 404 and return
    end

    qty = params[:quantity].to_i
    reason = params[:reason].to_s.strip
    damage_type = params[:damage_type].to_s.downcase

    if qty <= 0
      render json: { success: false, message: "Quantity must be greater than zero" } and return
    end

    ActiveRecord::Base.transaction do
      if damage_type == "bottle"
        # Bottle damage
        if qty > item.current_quantity
          render json: { success: false, message: "Quantity exceeds available stock" } and return
        end

        item.update!(current_quantity: item.current_quantity - qty)

      else
        # Pack damage
        labels = PrepackLabel.where(
          prepack_id: prepack.id,
          voided: 0,
          deleted: 0,
          dispensed: 0
        ).order(:id).limit(qty)

        if labels.count < qty
          render json: { success: false, message: "Not enough unvoided packs available" } and return
        end

        # Void labels
        labels.update_all(voided: 1, updated_at: Time.current)

        # Calculate total units lost
        total_units_lost = prepack.quantity_per_pack * qty
        
        current_num_packs_value = prepack.current_num_packs
        
        if current_num_packs_value == 0
          current_num_packs_value = prepack.num_packs
        end
        
        # Update all fields
        prepack.update!(
          current_num_packs: current_num_packs_value - qty,
          total_quantity: prepack.total_quantity - total_units_lost
        )
      end

      # Log the damage
      Damage.create!(
        general_inventory_id: item.gn_inventory_id,
        gn_identifier: item.gn_identifier,
        quantity: qty,
        reason: reason,
        reported_by: User.current.id,
        location_id: session[:location] || User.current.location_id,
        damage_date: Time.current,
        damage_type: damage_type,
        prepack_id: prepack.id
      )
    end

    render json: { success: true }

  rescue => e
    Rails.logger.error "Damage reporting failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { success: false, message: "Failed to record damage: #{e.message}" }, status: 500
  end

end