Rails.application.routes.draw do
  resource :session

  resources :orders, only: [ :index, :new, :create, :show ]

  namespace :admin do
    resources :dishes
    resources :daily_menus do
      resources :menu_items, only: [ :create, :update, :destroy ]
    end
  end

  namespace :chef do
    get "dashboard", to: "dashboard#show", as: :dashboard
  end

  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"
end
