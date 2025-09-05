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

    if @is_dispensary
      backstore_location = Location.find_by_name("Backstore")&.id || 5

      # Only load categories
      @available_categories = GeneralInventory
                                .joins(drug: :drug_category)
                                .where(location_id: backstore_location, voided: false)
                                .where("current_quantity > 0")
                                .distinct
                                .pluck("drug_categories.category")
                                .sort

      # NEW: If drug_id is passed, get its total available
      if params[:drug_id].present?
        @available_quantity = GeneralInventory
                                .where(location_id: backstore_location, voided: false, drug_id: params[:drug_id])
                                .sum(:current_quantity)
      else
        @available_quantity = nil
      end
    else
      @current_drug_categories = DrugCategory.all.pluck(:category)
    end

    render layout: "touch"
  end

  def create
    dispensary_loc = Location.find_by_name("Dispensary")&.id
    is_dispensary = session[:location] == dispensary_loc

    inventory_params = params[:general_inventory] || {}

    drug_name     = inventory_params[:drug_name].to_s.strip
    drug_category = inventory_params[:drug_category].to_s.strip

    # For backstore additions, do NOT join general_inventories
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

    if is_dispensary
      requested_qty = inventory_params[:amount_requested].to_s.strip.to_i

      if requested_qty <= 0
        flash[:errors] = "Quantity must be greater than 0"
        redirect_to "/" and return
      end

      total_qty = requested_qty * iterations

      begin
        Request.transaction do
          request = Request.new(
            drug_id:   drug_id,
            location_id: session[:location],
            quantity:  total_qty,
            fulfilled: false
          )

          unless request.save
            raise ActiveRecord::Rollback, request.errors.full_messages.join(", ")
          end
        end

        flash[:success] = "#{iterations} request(s) for #{drug_name} (total qty: #{total_qty}) submitted successfully."
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
          location_id:       session[:location]
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
#    raise params[:id].inspect
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
    entry = GeneralInventory
              .includes(:drug)
              .find_by(gn_identifier: params[:id], location_id: session[:location], voided: false)

    if entry.blank?
      render plain: 'false'
    else
      render json: {
        name: entry.drug.name,
        currentQty: entry.current_quantity
      }
    end
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

    # Show the total issued quantity across all locations
    # total_issued = Issue.where(inventory_id: GeneralInventory.where(gn_identifier: @item.gn_identifier).pluck(:gn_inventory_id)).sum(:quantity)
  end

  def list
    @drug = Drug.find_by_drug_id(params[:drug_id])
    @inventory = GeneralInventory.where("current_quantity > ? and drug_id = ? and location_id = ? and voided = ?",
                                        0, params[:drug_id] ,session[:location], false)
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
#    raise params[:id].inspect
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
end