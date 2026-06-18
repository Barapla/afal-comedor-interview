class Chef::BaseController < ApplicationController
  before_action :require_chef

  private
    def require_chef
      redirect_to root_path, alert: "No autorizado." unless Current.user&.chef? || Current.user&.admin?
    end
end
