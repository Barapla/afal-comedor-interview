# frozen_string_literal: true

class GuestsController < ApplicationController
  before_action :set_guest, only: %i[show edit update destroy]

  def index
    @guests = Current.user.guests.order(:name)
  end

  def show; end

  def new
    @guest = Current.user.guests.build
  end

  def edit; end

  def create
    @guest = Current.user.guests.build(guest_params)
    if @guest.save
      redirect_to @guest, notice: "Invitado registrado correctamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @guest.update(guest_params)
      redirect_to @guest, notice: "Invitado actualizado correctamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @guest.destroy
    redirect_to guests_path, notice: "Invitado eliminado."
  end

  private

  def set_guest
    @guest = Current.user.guests.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to guests_path, alert: "Invitado no encontrado."
  end

  def guest_params
    params.require(:guest).permit(:name)
  end
end
