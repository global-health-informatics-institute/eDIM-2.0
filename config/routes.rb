Rails.application.routes.draw do

  get 'prescriptions/index'

  get 'prescriptions/show'

  get 'prescriptions/create'

  get 'prescriptions/edit'

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  root 'main#index'

  ###################### Main Controller ##################################
  get "/main/settings"
  get "/select_report" => "main#select_report"
  post "/main/dispensation_report"
  post "/main/prescription_report"
  post "/main/stores_report"
  get "/time" => "main#time"

  ###################### Drug Controller ##################################
  get "/drug/search"
  get "/void_drug/:id" => "drug#destroy"
  post "/edit_drug" => "drug#edit"

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
  
  get "/requested_items", to: "general_inventory#requested", as: :requested_items
  post '/requests/:id/fulfill', to: 'requests#fulfill', as: :fulfill_request

  ###################### User Controller #############################
  get "/username_availability" => "user#username_availability"

  get "/query_users" => "user#query"
  get "/void_user/:id" => "user#destroy"
  post "/edit_user" => "user#edit"
  get "/user/users_names"

  ###################### Prescription Controller ##############################
  get "/void_prescriptions/:id" => "prescription#destroy"
  get "/prescriptions" => "prescription#ajax_prescriptions"
  post "/prescription/dispense"
  post "/prescription/edit"


  ###################### Dispensation Controller ##############################
  get "/print_dispensation_label/:id" => "dispensation#print_dispensation_label"
  get "/void_dispensation/:id" => "dispensation#destroy"
  

  ###################### Mobile Visit Controller ##############################
  get "/void_mobile_visit/:id" => "mobile_visit#destroy"

  ###################### Mobile Visit Product Controller ######################
  get "/void_mobile_visit_product/:id" => "mobile_visit_product#destroy"
  
  ###################### Drugs Controller ##############################
  get '/drug/available_quantity', to: 'drug#available_quantity'


  resources :mobile_visit
  resources :mobile_visit_product
  resources :drug_threshold
  resources :prescriptions
  resources :drug
  resources :patient_identifiers

  resources :drug, only: [:index, :new, :create, :edit, :destroy] do
    collection do
      get :available_quantity
    end
  end

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
  end

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

  resources :dispensation do
    collection do
      post 'refill'
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
      post 'login' , action: :create
      get 'logout' , action: :destroy
      get 'add_location'
      post 'workstation_location'
    end
  end
end
