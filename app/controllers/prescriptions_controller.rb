class PrescriptionsController < ApplicationController
  def index
  end

  def show
    @prescription = Prescription.find(params[:id])
    @suggestions = GeneralInventory.select(:gn_identifier,:expiration_date,
                                          :current_quantity).where('drug_id in (?) and current_quantity > ?
                                                                    and voided = ? and location_id = ?',
                                                                   @prescription.drug_id, 0, false,
                                                                   session[:location]).order(expiration_date: :asc).limit(5)
    @patient = @prescription.patient rescue nil
    @return_path = ("/patients/#{@prescription.patient_id}" || "/")
  end

  def new

  end

  def create
  end

  def edit
  end

  def update

  end

  def destroy
    prescription = Prescription.find(params[:id])
    prescription.update_attributes(:voided => true)
    redirect_to "/"
  end
end
