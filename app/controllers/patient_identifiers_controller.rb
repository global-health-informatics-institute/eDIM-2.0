class PatientIdentifiersController < ApplicationController
  def show
    identifier = BillingPatientIdentifier.find_by_identifier(params[:id])
    
    if identifier.blank?
      if anonymous_dispensation
        @item = GeneralInventory.find_by_gn_identifier(params[:id])
        redirect_to "/general_inventory/#{params[:id]}" and return if @item.present?
      end
      flash[:errors] = "Patient with ID #{params[:id]} not found"
      redirect_to root_path and return
    end
    
    @patient = BillingPatient.find(identifier.patient_id)
    redirect_to patient_path(@patient)
  end
end
