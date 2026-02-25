class IssuesController < ApplicationController

  def new
    @locations = Location.where.not(location_id: session[:location])
    @drug_id = params[:drug_id]
    @request_id = params[:request_id]

    # Prefill amount if this is a requested issue
    if @request_id.present?
      request = Request.find_by(id: @request_id)
      @prefill_amount = request&.quantity
    else
      @prefill_amount = nil
    end

    render layout: 'touch'
  end


  def create
    request = Request.find(params[:request_id])
    issued_quantity = params[:amount_issued].to_i
    target_location = Location.find_by(name: params[:location])

    source_stock = GeneralInventory.find_by(
      gn_identifier: request.gn_identifier,
      location_id: 5,  # Backstore
      drug_id: request.drug_id
    )

    if source_stock.nil? || source_stock.current_quantity < issued_quantity
      flash[:errors] = "Insufficient stock in Backstore for #{request.drug.name}"
      redirect_to "/issues/new?drug_id=#{request.drug_id}&request_id=#{request.id}" and return
    end

    dest_stock = nil

    ActiveRecord::Base.transaction do
      # Deduct from Backstore
      source_stock.update!(current_quantity: source_stock.current_quantity - issued_quantity)

      # Add to destination
      dest_stock = GeneralInventory.find_or_initialize_by(
        gn_identifier: source_stock.gn_identifier,
        location_id: target_location.id,
        drug_id: source_stock.drug_id
      )
      dest_stock.received_quantity ||= 0
      dest_stock.current_quantity ||= 0
      dest_stock.received_quantity += issued_quantity
      dest_stock.current_quantity += issued_quantity
      dest_stock.expiration_date ||= source_stock.expiration_date
      dest_stock.date_received ||= Date.current
      dest_stock.save!

      # Create issue record
      Issue.create!(
        inventory_id: source_stock.id,
        location_id: source_stock.location_id,
        issued_to: dest_stock.location_id,
        issued_by: session[:user_id],
        quantity: issued_quantity,
        issue_date: DateTime.current
      )

      # Ensure quantity_received is incremented properly
      request.with_lock do
        request.quantity_received ||= 0
        request.quantity_received += issued_quantity

        # Mark as fulfilled if total issued >= requested quantity
        if request.quantity_received >= request.quantity
          request.fulfilled = true
          request.fulfilled_at = DateTime.current
          request.fulfilled_by = session[:user_id]
        end

        request.save!
      end
    end

    flash[:success] = "#{issued_quantity} units of #{request.drug.name} issued successfully."
    print_and_redirect("/print_bottle_barcode/#{dest_stock.id}", "/requests")
  rescue => e
    flash[:errors] = "Error issuing stock: #{e.message}"
    redirect_to "/issues/new?drug_id=#{request.drug_id}&request_id=#{request.id}"
  end

  def update
  end

  def show
  end

  def list
    case params[:report_duration]
    when t('forms.options.daily')
      @report_type = "Issues Report for #{l(params[:start_date].to_date, format:'%d %B, %Y')}"
      start_date = params[:start_date].to_date.beginning_of_day
      end_date   = params[:start_date].to_date.end_of_day

    when t('forms.options.weekly')
      start_date = params[:start_date].to_date.beginning_of_day
      end_date   = (start_date + 6.days).end_of_day

      @report_type = "Issues Report from #{l(start_date.to_date, format:'%d %B, %Y')} #{t('menu.terms.to')} #{l(end_date.to_date, format: '%d %B, %Y')}"

    when t('forms.options.monthly')
      start_date = params[:start_date].to_date.beginning_of_day
      end_date   = (params[:start_date].to_date + 1.month - 1.day).end_of_day

      @report_type = "Issues Report from #{l(start_date.to_date, format:'%d %B, %Y')} #{t('menu.terms.to')} #{l(end_date.to_date, format: '%d %B, %Y')}"

    when t('forms.options.range')
      start_date = params[:start_date].to_date.beginning_of_day
      end_date   = params[:end_date].to_date.end_of_day

      @report_type = "Issues Report from #{l(start_date, format:'%d %B, %Y')} #{t('menu.terms.to')} #{l(end_date, format: '%d %B, %Y')}"
    end

    if params[:locations].include? 'All Locations'
      @records = Issue.where(issue_date: start_date..end_date, voided: false)
    else
      locations = Location.where(name: params[:locations]).pluck(:location_id)
      @records = Issue.where(issue_date: start_date..end_date, location_id: locations, voided: false)
    end
  end

  def select
    locations = GeneralInventory.where(gn_inventory_id: Issue.all.pluck(:inventory_id)).pluck(:location_id)
    @locations = ['All Locations'] + Location.where(location_id: locations.uniq).pluck(:name)
    render layout: 'touch'
  end
end
