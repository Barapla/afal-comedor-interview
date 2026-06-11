class HomeController < ApplicationController
  def index
    case Current.user&.role
    when "admin" then redirect_to admin_dishes_path
    when "chef"  then redirect_to chef_dashboard_path
    else              redirect_to orders_path
    end
  end
end
