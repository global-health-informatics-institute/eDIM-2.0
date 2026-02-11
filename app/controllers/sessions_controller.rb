class SessionsController < ApplicationController
skip_before_action :verify_authenticity_token, only: :create

  def new
    preserved_flash = flash.to_hash.symbolize_keys

    reset_session
    session[:user_id] = nil
    User.current = nil

    preserved_flash.each do |key, value|
      flash[key] = value
    end

    render :layout => "touch"
  end
  
def create
  state = User.authenticate(params['login'],params['password'])

  if state
    user = User.find_by_username(params['login'])
    session[:user_id] = user.id
    session[:user] = user.username  
    User.current = user
    flash[:errors] = nil
    redirect_to '/sessions/add_location' and return
  else
    flash[:error] = t("messages.invalid_credentials")
    redirect_to "/sessions/new"
  end
end


  def add_location
    render :layout => 'touch'
  end

  def workstation_location
    location = Location.find(params[:location]) rescue nil
    location ||= Location.find_by_id(params[:location]) rescue nil

    Rails.logger.info "Params location: #{params[:location].inspect}"
    Rails.logger.info "Found location: #{location.inspect}"
    Rails.logger.info "Is a workstation? #{location.is_a_workstation? if location}"

    if location.blank? || location.is_a_workstation?
      Rails.logger.warn "Invalid workstation location"
      flash[:error] = "Invalid workstation location"
      redirect_to '/sessions/add_location' and return
    else
      Rails.logger.info "Valid workstation location, proceeding"
      session[:location] = location.id
      redirect_to root_path
    end
  end


  def destroy
    session[:location] = nil
    session[:user_id] = nil
    User.current = nil
    redirect_to "/sessions/new"
  end

  private

  def check_logged_in
    unless session[:user_id].present?
      flash[:error]="you're session has expired.please login again"
      redirect_to "/sessions/new"
    end
  end

  def redirect_if_logged_in
    if session[:user_id].present?
      flash[:info]="you are already logged in"
      redirect_to "/sessions/add_location"
    end
  end


  #class ApplicationController <ActionController::Base

    #auto_session_timeout 30.minutes
  #end

end
