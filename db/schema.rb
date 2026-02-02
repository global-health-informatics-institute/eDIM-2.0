# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2026_02_02_141332) do
  create_table "app_options", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_app_options_on_name", unique: true
  end

  create_table "damages", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "general_inventory_id", null: false
    t.integer "quantity", default: 0, null: false
    t.string "reason"
    t.integer "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "reported_by"
    t.integer "location_id"
    t.datetime "damage_date"
    t.string "gn_identifier"
    t.string "damage_type", default: "pack", null: false
    t.bigint "prepack_id"
    t.index ["damage_type"], name: "index_damages_on_damage_type"
    t.index ["general_inventory_id"], name: "index_damages_on_general_inventory_id"
    t.index ["gn_identifier"], name: "index_damages_on_gn_identifier"
    t.index ["prepack_id"], name: "index_damages_on_prepack_id"
  end

  create_table "dispensations", primary_key: "dispensation_id", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "rx_id"
    t.string "inventory_id"
    t.integer "patient_id"
    t.integer "quantity"
    t.datetime "dispensation_date", precision: nil
    t.integer "dispensed_by"
    t.boolean "voided", default: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "drug_categories", primary_key: "drug_category_id", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "category"
    t.boolean "voided", default: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "drug_thresholds", primary_key: "threshold_id", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "drug_id"
    t.integer "threshold"
    t.boolean "voided", default: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "drugs", primary_key: "drug_id", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "drug_category_id"
    t.string "name"
    t.string "dose_strength"
    t.string "dose_form", null: false
    t.boolean "voided", default: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "par_level"
    t.string "item_code"
  end

  create_table "edim_patients", primary_key: "patient_id", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "given_name", limit: 50
    t.string "family_name", limit: 50
    t.string "full_name", limit: 120
    t.string "gender", limit: 1
    t.date "birthdate"
    t.string "identifier", limit: 50
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "arrival_time", precision: nil
    t.datetime "departure_time", precision: nil
    t.index ["arrival_time"], name: "index_edim_patients_on_arrival_time"
    t.index ["departure_time"], name: "index_edim_patients_on_departure_time"
    t.index ["identifier"], name: "index_edim_patients_on_identifier", unique: true
  end

  create_table "edim_visits", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "edim_patient_id", null: false
    t.datetime "arrival_time", null: false
    t.datetime "departure_time"
    t.date "visit_date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["edim_patient_id", "visit_date"], name: "index_edim_visits_on_edim_patient_id_and_visit_date"
  end

  create_table "general_inventories", primary_key: "gn_inventory_id", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "drug_id"
    t.string "gn_identifier"
    t.date "expiration_date"
    t.date "date_received"
    t.integer "received_quantity", default: 0
    t.integer "current_quantity", default: 0
    t.integer "location_id", null: false
    t.integer "created_by"
    t.boolean "voided", default: false
    t.string "void_reason"
    t.integer "voided_by"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "gn_sequence"
    t.integer "reorder_level", default: 10, null: false
    t.index ["gn_identifier"], name: "index_general_inventories_on_gn_identifier"
  end

  create_table "issues", primary_key: "issue_id", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "inventory_id"
    t.integer "location_id"
    t.integer "issued_to"
    t.integer "quantity"
    t.datetime "issue_date", precision: nil
    t.integer "issued_by"
    t.boolean "voided", default: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "location", primary_key: "location_id", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "description"
    t.string "address1"
    t.string "address2"
    t.string "city_village"
    t.string "state_province"
    t.string "country"
    t.string "postal_code"
    t.boolean "voided", default: false
    t.integer "creator"
    t.datetime "date_created"
    t.integer "changed_by"
    t.datetime "date_changed"
    t.string "uuid"
    t.string "neighborhood_cell"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_location_on_name"
  end

  create_table "location_tag", primary_key: "location_tag_id", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.boolean "retired", default: false
    t.integer "creator"
    t.datetime "date_created"
    t.integer "retired_by"
    t.datetime "date_retired"
    t.string "retire_reason"
    t.string "uuid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_location_tag_on_name"
  end

  create_table "location_tag_map", id: false, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "location_tag_id", null: false
    t.integer "location_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["location_tag_id", "location_id"], name: "index_location_tag_map_on_location_tag_id_and_location_id", unique: true
  end

  create_table "mobile_visit", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.date "visit_date", null: false
    t.integer "visit_supervisor", null: false
    t.text "notes"
    t.boolean "voided", default: false
    t.integer "creator"
    t.datetime "date_created"
    t.integer "changed_by"
    t.datetime "date_changed"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["visit_supervisor"], name: "index_mobile_visit_on_visit_supervisor"
  end

  create_table "mobile_visit_products", primary_key: "mvp_id", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "mobile_visit_id"
    t.string "gn_identifier"
    t.integer "amount_taken"
    t.integer "amount_used"
    t.boolean "voided", default: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "mobile_visits", primary_key: "mobile_visit_id", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.date "visit_date"
    t.integer "visit_supervisor"
    t.boolean "voided", default: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "patient", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "person_id", null: false
    t.boolean "voided", default: false
    t.integer "creator"
    t.datetime "date_created"
    t.integer "changed_by"
    t.datetime "date_changed"
    t.boolean "dead", default: false
    t.datetime "death_date"
    t.integer "cause_of_death"
    t.boolean "patient_id_card_printed", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id"], name: "index_patient_on_person_id"
  end

  create_table "patient_identifier", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "patient_id", null: false
    t.integer "identifier_type", null: false
    t.string "identifier", null: false
    t.boolean "preferred", default: false
    t.boolean "voided", default: false
    t.integer "creator"
    t.datetime "date_created"
    t.integer "changed_by"
    t.datetime "date_changed"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["identifier_type"], name: "index_patient_identifier_on_identifier_type"
    t.index ["patient_id", "identifier_type"], name: "index_patient_identifier_on_patient_id_and_identifier_type", unique: true
    t.index ["patient_id"], name: "index_patient_identifier_on_patient_id"
  end

  create_table "patient_identifier_type", primary_key: "patient_identifier_type_id", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.boolean "retired", default: false
    t.integer "creator"
    t.datetime "date_created"
    t.integer "retired_by"
    t.datetime "date_retired"
    t.string "retire_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "person", primary_key: "person_id", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.boolean "voided", default: false
    t.integer "creator"
    t.datetime "date_created"
    t.integer "changed_by"
    t.datetime "date_changed"
    t.boolean "dead", default: false
    t.date "birthdate"
    t.boolean "birthdate_estimated", default: false
    t.date "death_date"
    t.integer "cause_of_death"
    t.integer "gender"
    t.string "gender_string"
    t.integer "death_reason"
    t.integer "death_place"
    t.string "death_place_other"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "person_address", primary_key: "person_address_id", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "person_id", null: false
    t.string "address1"
    t.string "address2"
    t.string "address3"
    t.string "city_village"
    t.string "state_province"
    t.string "country"
    t.string "postal_code"
    t.boolean "preferred", default: false
    t.boolean "voided", default: false
    t.integer "creator"
    t.datetime "date_created"
    t.integer "changed_by"
    t.datetime "date_changed"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id"], name: "index_person_address_on_person_id"
  end

  create_table "person_attribute", primary_key: "person_attribute_id", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "person_id", null: false
    t.integer "person_attribute_type_id", null: false
    t.text "value"
    t.integer "creator"
    t.datetime "date_created"
    t.boolean "voided", default: false
    t.integer "voided_by"
    t.datetime "date_voided"
    t.string "void_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["person_attribute_type_id"], name: "index_person_attribute_on_person_attribute_type_id"
    t.index ["person_id"], name: "index_person_attribute_on_person_id"
  end

  create_table "person_attribute_type", primary_key: "person_attribute_type_id", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.boolean "retired", default: false
    t.integer "retired_by"
    t.datetime "date_retired"
    t.string "retire_reason"
    t.integer "creator"
    t.datetime "date_created"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "person_name", primary_key: "person_name_id", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "person_id", null: false
    t.string "given_name"
    t.string "middle_name"
    t.string "family_name"
    t.string "family_name2"
    t.string "family_name_suffix"
    t.boolean "preferred", default: false
    t.boolean "voided", default: false
    t.integer "creator"
    t.datetime "date_created"
    t.integer "changed_by"
    t.datetime "date_changed"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id"], name: "index_person_name_on_person_id"
  end

  create_table "person_name_code", primary_key: "person_name_code_id", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "person_name_id", null: false
    t.string "given_name_code"
    t.string "middle_name_code"
    t.string "family_name_code"
    t.string "family_name2_code"
    t.string "family_name_suffix_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["person_name_id"], name: "index_person_name_code_on_person_name_id"
  end

  create_table "prepack_labels", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "prepack_id", null: false
    t.integer "bottle_id", null: false
    t.string "label_identifier", null: false
    t.boolean "dispensed", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "dispensed_by"
    t.datetime "date_dispensed"
    t.boolean "voided", default: false
    t.boolean "deleted", default: false
    t.index ["bottle_id"], name: "fk_rails_03e2d3a9d7"
    t.index ["label_identifier"], name: "index_prepack_labels_on_label_identifier", unique: true
    t.index ["prepack_id"], name: "index_prepack_labels_on_prepack_id"
  end

  create_table "prepacks", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "bottle_id", null: false
    t.integer "drug_id", null: false
    t.integer "quantity_per_pack", null: false
    t.integer "num_packs", null: false
    t.integer "total_quantity", null: false
    t.string "directions"
    t.bigint "prepacked_by_id", null: false
    t.string "status", default: "created", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "gn_identifier"
    t.integer "location_id"
    t.integer "current_num_packs", default: 0, null: false
    t.boolean "voided", default: false, null: false
    t.boolean "deleted", default: false, null: false
    t.string "pack_identifier"
    t.text "times", size: :long, collation: "utf8mb4_bin"
    t.index ["bottle_id"], name: "fk_rails_7c59771cdf"
    t.index ["deleted"], name: "index_prepacks_on_deleted"
    t.index ["drug_id"], name: "fk_rails_10a6425e68"
    t.index ["gn_identifier"], name: "index_prepacks_on_gn_identifier"
    t.index ["prepacked_by_id"], name: "fk_rails_9a9ad1026f"
    t.index ["status"], name: "index_prepacks_on_status"
    t.index ["voided"], name: "index_prepacks_on_voided"
  end

  create_table "prescriptions", primary_key: "rx_id", id: :integer, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "patient_id"
    t.integer "drug_id"
    t.datetime "date_prescribed", precision: nil
    t.integer "quantity"
    t.integer "amount_dispensed"
    t.string "directions"
    t.integer "provider_id"
    t.boolean "voided", default: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "times"
  end

  create_table "requests", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "drug_id", null: false
    t.integer "location_id", null: false
    t.integer "quantity", null: false
    t.boolean "fulfilled", default: false
    t.datetime "fulfilled_at"
    t.integer "fulfilled_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "role", primary_key: "role", id: :string, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "description"
    t.integer "creator"
    t.datetime "date_created"
    t.boolean "voided", default: false
  end

  create_table "user_property", id: false, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "property", null: false
    t.text "property_value"
    t.integer "creator"
    t.datetime "date_created"
    t.boolean "voided", default: false
    t.index ["user_id", "property"], name: "index_user_property_on_user_id_and_property", unique: true
    t.index ["user_id"], name: "index_user_property_on_user_id"
  end

  create_table "user_role", id: false, charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "role", null: false
    t.integer "creator"
    t.datetime "date_created"
    t.boolean "voided", default: false
    t.index ["role"], name: "index_user_role_on_role"
    t.index ["user_id", "role"], name: "index_user_role_on_user_id_and_role", unique: true
    t.index ["user_id"], name: "index_user_role_on_user_id"
  end

  create_table "users", primary_key: "user_id", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "person_id"
    t.string "username", null: false
    t.string "password", null: false
    t.string "salt"
    t.boolean "voided", default: false
    t.integer "creator"
    t.datetime "date_created"
    t.datetime "date_changed"
    t.integer "changed_by"
    t.boolean "retired", default: false
    t.integer "retired_by"
    t.datetime "date_retired"
    t.string "retire_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id"], name: "index_users_on_person_id"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "damages", "prepacks"
  add_foreign_key "edim_visits", "edim_patients", primary_key: "patient_id"
  add_foreign_key "prepack_labels", "general_inventories", column: "bottle_id", primary_key: "gn_inventory_id"
  add_foreign_key "prepack_labels", "prepacks"
  add_foreign_key "prepacks", "drugs", primary_key: "drug_id"
  add_foreign_key "prepacks", "general_inventories", column: "bottle_id", primary_key: "gn_inventory_id"
  add_foreign_key "prepacks", "users", column: "prepacked_by_id", primary_key: "user_id"
end
