class DrugController < ApplicationController

  def search
    category = DrugCategory.find_by_category(params[:filter_value])
    return render html: "".html_safe if category.nil?

    # For both dispensary add and backstore add: return all drugs in the category
    drugs = Drug.where(voided: false, drug_category_id: category.id)

    if params[:search_string].present?
      drugs = drugs.where("drugs.name LIKE ?", "%#{params[:search_string]}%")
    end

    drug_items = drugs.map do |v|
      "<li value='#{v.name}'>#{v.name}</li>"
    end

    render html: drug_items.join('').html_safe
  end

  private

  # Detect dispensary
  def in_dispensary?
    dispensary = Location.find_by(name: "Dispensary")
    session[:location].to_i == dispensary&.id.to_i
  end

  # Helper to get current location ID
  def current_location_id
    session[:location].to_i
  end

  def index
    @drugs = Drug.where("voided = ?", false)
  end

  def destroy
    drug = Drug.where("drug_id = ?", params[:id]).first rescue nil
    if drug.blank?
      flash[:errors][:missing] = "Item was not found"
    else
      drug.voided =  true
      drug.save
      if drug.errors.blank?
        flash[:success] = "#{drug.name} was successfully deleted."
      else
        flash[:errors] = drug.errors.join(",")
      end
    end
    redirect_to "/drug" and return
  end

  def new
    render :layout => 'touch'
  end

  def create

    begin
      drug_name = ((params[:drug_ingredient].to_s rescue "") + " " + (params[:dose_strength].to_s rescue "") + " " + (params[:dose_form].to_s rescue "")).squish
      drug = Drug.where(name: drug_name).first_or_initialize
      drug.drug_category_id = DrugCategory.find_by_category(params[:drug_category]).id
      drug.name = drug_name
      drug.dose_strength = (params[:dose_strength].blank? ? nil : params[:dose_strength].squish)
      drug.dose_form = (params[:dose_form].blank? ? nil : params[:dose_form].squish)
      drug.save
    rescue ex
      flash[:errors] = ex.message
    end

    if drug.errors.blank?
      flash[:success] = "#{drug.name} was successfully created."
    else
      flash[:errors] = drug.errors.join(" , ")
    end

    redirect_to "/drug" and return
  end

  def edit
    if request.post?
      begin
        drug_name = ((params[:drug_ingredient].to_s rescue "") + " " + (params[:dose_strength].to_s rescue "") + " " + (params[:dose_form].to_s rescue "")).squish
        drug = Drug.find(params[:drug_id])
        drug.drug_category_id = DrugCategory.find_by_category(params[:drug_category]).id
        drug.name = drug_name
        drug.dose_strength = (params[:dose_strength].blank? ? nil : params[:dose_strength].squish)
        drug.dose_form = (params[:dose_form].blank? ? nil : params[:dose_form].squish)
        drug.save
      rescue => ex
        flash[:errors] = ex.message
      end


      if drug.errors.blank?
        flash[:success] = "#{drug.name} was successfully edited."
      else
        flash[:errors] = drug.errors.join(" , ")
      end

      redirect_to "/drug" and return
    else
      @drug = Drug.find(params[:id])
      render :layout => 'touch'
    end

  end

  # GET drug avaiable quantity
    def available_quantity
      drug_name = params[:drug_name].to_s.strip
      backstore_location = Location.find_by_name("Backstore")&.id || 5

      if drug_name.blank?
        render json: { available: 0 } and return
      end

      # case-insensitive exact match
      drug = Drug.where("LOWER(name) = ?", drug_name.downcase).first

      if drug
        # Sum current_quantity for this drug in the backstore
        available = GeneralInventory.where(drug_id: drug.id, location_id: backstore_location, voided: false)
                                    .sum(:current_quantity)
        render json: { available: available, drug_id: drug.id }
      else
        render json: { available: 0 }
      end
    end

end
