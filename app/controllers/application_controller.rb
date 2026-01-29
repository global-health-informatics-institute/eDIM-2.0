class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  before_action :check_logged_in, unless: :exempted_routes
  helper_method :current_user

  def print_and_redirect(print_url, redirect_url, message = "Printing label ...", show_next_button = false, patient_id = nil)
    @print_url = print_url
    @redirect_url = redirect_url
    @message = message
    @show_next_button = show_next_button

    render html: <<-HTML.html_safe
      <!DOCTYPE html>
      <html>
      <head>
        <title>Printing...</title>
        <meta charset="UTF-8">
      </head>
      <body>
        <p>#{@message}</p>
        <iframe src="#{@print_url}" style="display:none;"></iframe>
        <script type="text/javascript">
          setTimeout(function() {
            window.location = "#{@redirect_url}";
          }, 1000); // adjust delay if needed
        </script>
      </body>
      </html>
    HTML
  end

  def current_user
    @current_user ||= User.find_by_username(session[:user]) if session[:user]
  end

  def anonymous_dispensation
    YAML.load_file("#{Rails.root}/config/application.yml")['allow_anonymous_dispense'] rescue false
  end
  protected

def check_logged_in
  if session[:user_id].blank?
    flash[:error] = "Your session has expired. Please login again."  
    respond_to do |format|
      format.html { redirect_to "/sessions/new" }
    end
  elsif session[:user_id].present?  
    begin
      User.current = User.find(session[:user_id])
      I18n.locale = User.current.language || I18n.default_locale
    rescue ActiveRecord::RecordNotFound
    
      session[:user_id] = nil
      flash[:error] = "Your session is no longer valid. Please login again."
      redirect_to "/sessions/new" and return
    end
  end
end


  def exempted_routes
    ['/sessions/new','/sessions/login','/sessions/logout','/main/time'].include?(request.env['PATH_INFO'])
  end
end
