class RequestsController < ApplicationController
  before_action :set_pending_requests_count

  def index
    location = Location.find(session[:location])

    if location.name.downcase == "backstore"
      # Backstore sees all pending requests
      @requests = Request.where(fulfilled: false).includes(:drug)
    else
      # Other locations only see their own requests
      @requests = Request.where(location_id: session[:location], fulfilled: false).includes(:drug)
    end
  end

  def new
    @drugs = Drug.all
    render layout: "touch"
  end

  def create
    drug = Drug.find_by_name(params[:drug_name])
    if drug.blank?
      flash[:errors] = "Drug not found"
      redirect_to new_request_path and return
    end

    request = Request.new(
      drug_id: drug.id,
      location_id: session[:location],
      quantity: params[:quantity].to_i
    )

    if request.save
      flash[:success] = "Request for #{drug.name} created"
      redirect_to "/"
    else
      flash[:errors] = request.errors.full_messages.join(", ")
      redirect_to new_request_path
    end
  end

  def fulfill
    request = Request.find(params[:id])
    redirect_to new_issue_path(drug_id: request.drug_id, request_id: request.id)
  end

  # Step 2: Complete issuing from issuing form
  def complete_issue
    request = Request.find(params[:request_id])
    issue_qty = params[:quantity].to_i
    source_location_id = 5  # backstore

    # Find all available bottles for the requested drug at source
    available_bottles = GeneralInventory.where(
      drug_id: request.drug_id,
      location_id: source_location_id
    ).where("current_quantity > 0").order(:date_received).lock(true)

    remaining_qty = issue_qty

    ActiveRecord::Base.transaction do
      available_bottles.each do |bottle|
        break if remaining_qty <= 0

        to_issue = [bottle.current_quantity, remaining_qty].min

        # Reduce source
        bottle.update!(current_quantity: bottle.current_quantity - to_issue)

        # Increase destination
        dest_stock = GeneralInventory.find_or_initialize_by(
          gn_identifier: bottle.gn_identifier,
          location_id: request.location_id,
          drug_id: bottle.drug_id
        )
        dest_stock.current_quantity ||= 0
        dest_stock.received_quantity ||= 0
        dest_stock.current_quantity += to_issue
        dest_stock.received_quantity += to_issue
        dest_stock.expiration_date ||= bottle.expiration_date
        dest_stock.date_received ||= Date.current
        dest_stock.save!

        # Create Issue record
        Issue.create!(
          inventory_id: bottle.id,
          location_id: source_location_id,
          issued_to: request.location_id,
          issued_by: session[:user_id],
          quantity: to_issue,
          issue_date: DateTime.current
        )

        remaining_qty -= to_issue
      end

      if remaining_qty > 0
        raise ActiveRecord::Rollback, "Insufficient stock to fulfill request"
      else
        request.update!(
          fulfilled: true,
          fulfilled_at: Time.now,
          fulfilled_by: session[:user_id]
        )
      end
    end

    flash[:success] = "Request fulfilled successfully"
    redirect_to requests_path
  rescue => e
    flash[:error] = "Error: #{e.message}"
    redirect_to requests_path
  end

  private

  def set_pending_requests_count
    location = Location.find(session[:location])

    if location.name.downcase == "backstore"
      @pending_requests_count = Request.where(fulfilled: false).count
    else
      @pending_requests_count = Request.where(location_id: session[:location], fulfilled: false).count
    end
  end
end