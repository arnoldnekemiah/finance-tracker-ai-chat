Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes
  namespace :api do
    namespace :v1 do
      # Chat endpoints
      resources :chat, only: [] do
        collection do
          post :messages, to: "chat#create"
          get :conversations, to: "chat#index"
        end
      end
      get "chat/conversations/:id", to: "chat#show"

      # Notifications endpoints
      get "notifications/preferences", to: "notifications#show_preferences"
      put "notifications/preferences", to: "notifications#update_preferences"
      
      # Webhooks
      post "webhooks/fcm_token", to: "notifications#register_fcm_token"
    end
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
