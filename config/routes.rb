Rails.application.routes.draw do
  # Root
  root 'main#index'

  ###################### Main Controller ##################################
  get "/main/settings"
  post "/main/dispensation_report"
  post "/main/prescription_report"
  post "/main/stores_report"
  get "/time" => "main#time"

  ###################### Drug Controller ##################################
  get "/drug/search"
  get "/void_drug/:id" => "drug#destroy"
  post "/edit_drug" => "drug#edit"
  get '/drug/available_quantity', to: 'drug#available_quantity'

  ###################### General Inventory Controller #####################
  get "/void_general_inventory/:id" => "general_inventory#destroy"
  post "/void_general_inventory" => "general_inventory#destroy"
  post "/edit_general_inventory" => "general_inventory#edit"
  get "/general_inventory/expired_items"
  get "/general_inventory/expiring_items"
  get "/general_inventory/understocked"
  get "/general_inventory/wellstocked"
  get "view_gn_drug/:id" => "general_inventory#view_drug"
  get "/print_bottle_barcode/:id" => "general_inventory#print_bottle_barcode"
  get "/ajax_bottle/:id" => "general_inventory#ajax_bottle"
  get "/general_inventory/print_bottle_barcode"

  # Dispensary
  get '/dispensary/new', to: 'general_inventory#new', as: :new_dispensary_item
  post '/dispensary', to: 'general_inventory#create', as: :create_dispensary_item

  ###################### User Controller #############################
  get "/username_availability" => "user#username_availability"
  get "/query_users" => "user#query"
  get "/void_user/:id" => "user#destroy"
  post "/edit_user" => "user#edit"
  get "/user/users_names"

  ###################### Prescription Controller ######################
  get "/void_prescriptions/:id" => "prescription#destroy"
  get "/prescriptions" => "prescription#ajax_prescriptions"
  post "/prescription/dispense"
  post "/prescription/edit"

  ###################### Dispensation Controller ######################
  get "/print_dispensation_label/:id" => "dispensation#print_dispensation_label"
  get "/void_dispensation/:id" => "dispensation#destroy"

  ###################### Mobile Visit Controllers ######################
  get "/void_mobile_visit/:id" => "mobile_visit#destroy"
  get "/void_mobile_visit_product/:id" => "mobile_visit_product#destroy"

  ###################### Requests Controller ##########################
  get  'requests/select', to: 'requests#select',  as: 'select_requests_report'
  post 'requests/report', to: 'requests#report',  as: 'requests_report'
  get  'requests/list',   to: 'requests#list',    as: 'requests_list'
  post '/requests/:id/fulfill', to: 'requests#fulfill', as: :fulfill_request

  ###################### Dispensation Reports ##########################
  get '/select_report', to: 'dispensation#select', as: :select_report
  post '/dispensation/list', to: 'dispensation#list', as: :dispensation_list

  ###################### Prepack Labels Controller #####################
  # REMOVE THIS CONFLICTING LINE: get "/print_prepack_labels/:id" => "prepack_labels#show", as: :print_prepack_labels
  
  get '/general_inventory/prepack_labels', to: 'prepack_labels#new'
  get '/prepack_labels/delete/:id', to: 'prepack_labels#delete', as: 'delete_prepack_label'

  ###################### Resources #####################################

  # ONLY ONE resources :prepack_labels declaration
  resources :prepack_labels, only: [:show, :new, :create, :destroy] do
    collection do
      get 'ajax_bottle_prepack'
      # Add prepack report routes here
      get 'select'
      post 'report'
      get 'list'
    end
  end

  # Add this AFTER the resources declaration
  get "/print_prepack_labels/:id" => "prepack_labels#show", as: :print_prepack_labels

  resources :general_inventory do
    post 'pre_packing'
    collection do
      get 'print_pre_packed(/:id)', action: :print_pre_packed
      get 'list'
      post 'merge'
    end
  end

  resources :requests do
    member do
      post :fulfill
    end
    collection do
      get :select
    end
  end

  resources :dispensation do
    collection do
      get :list
      get :select
      post :refill
    end
  end

  resources :drug, only: [:index, :new, :create, :edit, :destroy] do
    collection do
      get :available_quantity
    end
  end

  resources :prescriptions
  resources :mobile_visit
  resources :mobile_visit_product
  resources :drug_threshold
  resources :patient_identifiers

  resources :patients do
    collection do
      get 'given_names'
      get 'family_names'
    end
  end

  resources :user do
    collection do
      get 'roles'
    end
  end

  resources :locations do
    collection do
      get 'search'
      get 'print_label'
      get 'suggestions'
    end
  end

  resources :issues do
    collection do
      get 'select'
      post 'list'
    end
  end

  resources :sessions do
    collection do
      post 'login', action: :create
      get 'logout', action: :destroy
      get 'add_location'
      post 'workstation_location'
    end
  end
end