class RequestsController < ApplicationController
  def index
    # Only show pending requests if user is in backstore
    if session[:location] == Location.backstore_id
      @requests = Request.where(fulfilled: false).includes(:drug)
    else
      @requests = Request.where(location_id: session[:location]).includes(:drug)
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
    request.update(
      fulfilled: true,
      fulfilled_at: Time.now,
      fulfilled_by: session[:user_id]
    )
    redirect_to new_issue_path(drug_id: request.drug_id, request_id: request.id)
  end
end