class DrugController < ApplicationController

  def search
    drugs = Drug.where("voided = ? and name like ? and drug_category_id = ? ", false, "%#{params[:search_string]}%",
               DrugCategory.find_by_category(params[:filter_value]).id) rescue []
    drug_names = drugs.map do |v|
      "<li value='#{v.name.html_safe}'>#{v.name.html_safe}</li>"
    end
    render html: drug_names.join('').html_safe and return
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
end
