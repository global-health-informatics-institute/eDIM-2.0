class SessionsController < ApplicationController

  def new
    session[:user_id] = nil
    User.current = nil
    render :layout => "touch"
  end
  def create
    state = User.authenticate(params['login'],params['password'])

    if state
      user = User.find_by_username(params['login'])
      session[:user_id] = user.id
      User.current = user
      flash[:errors] = nil
      redirect_to '/sessions/add_location' and return
    else
      flash[:errors] = t("messages.invalid_credentials")
      redirect_to "/sessions/new"
    end
  end

  def add_location
    render :layout => 'touch'
  end

  def workstation_location
    location = Location.find(params[:location]) rescue nil
    location ||= Location.find_by_name(params[:location]) rescue nil

    Rails.logger.info "Params location: #{params[:location].inspect}"
    Rails.logger.info "Found location: #{location.inspect}"
    Rails.logger.info "Is a workstation? #{location.is_a_workstation? if location}"

    if location.blank? || !location.is_a_workstation?
      Rails.logger.warn "Invalid workstation location detected"
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
end
