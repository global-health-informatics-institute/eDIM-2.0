class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
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
        <titles style="font-size: 1.7rem;">Printing label ...</title>
        <meta charset="UTF-8">
      </head>
      <body>
        <p>#{@message}</p>
        <iframe src="#{@print_url}" style="display:none;"></iframe>
        <script type="text/javascript">
          setTimeout(function() {
            window.location = "#{@redirect_url}";
          }, 1000);
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
      respond_to do |format|
        format.html { redirect_to "/sessions/new" }
      end
    elsif not session[:user_id].blank?
      User.current = User.find(session[:user_id])
      I18n.locale = User.current.language || I18n.default_locale
    end
  end

  def exempted_routes
    ['/sessions/new','/sessions/login','/sessions/logout','/main/time'].include?(request.env['PATH_INFO'])
  end
end
