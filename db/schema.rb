# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20250808094818) do

  create_table "dispensations", primary_key: "dispensation_id", force: :cascade do |t|
    t.integer  "rx_id",             limit: 4
    t.string   "inventory_id",      limit: 255
    t.integer  "patient_id",        limit: 4
    t.integer  "quantity",          limit: 4
    t.datetime "dispensation_date"
    t.integer  "dispensed_by",      limit: 4
    t.boolean  "voided",                        default: false
    t.datetime "created_at",                                    null: false
    t.datetime "updated_at",                                    null: false
  end

  create_table "drug_categories", primary_key: "drug_category_id", force: :cascade do |t|
    t.string   "category",   limit: 255
    t.boolean  "voided",                 default: false
    t.datetime "created_at",                             null: false
    t.datetime "updated_at",                             null: false
  end

  create_table "drug_thresholds", primary_key: "threshold_id", force: :cascade do |t|
    t.string   "drug_id",    limit: 255
    t.integer  "threshold",  limit: 4
    t.boolean  "voided",                 default: false
    t.datetime "created_at",                             null: false
    t.datetime "updated_at",                             null: false
  end

  create_table "drugs", primary_key: "drug_id", force: :cascade do |t|
    t.integer  "drug_category_id", limit: 4
    t.string   "name",             limit: 255
    t.string   "dose_strength",    limit: 255
    t.string   "dose_form",        limit: 255,                 null: false
    t.boolean  "voided",                       default: false
    t.datetime "created_at",                                   null: false
    t.datetime "updated_at",                                   null: false
    t.integer  "par_level",        limit: 4
    t.string   "item_code",        limit: 255
  end

  create_table "general_inventories", primary_key: "gn_inventory_id", force: :cascade do |t|
    t.integer  "drug_id",           limit: 4
    t.string   "gn_identifier",     limit: 255
    t.date     "expiration_date"
    t.date     "date_received"
    t.integer  "received_quantity", limit: 4,   default: 0
    t.integer  "current_quantity",  limit: 4,   default: 0
    t.integer  "location_id",       limit: 4,                   null: false
    t.integer  "created_by",        limit: 4
    t.boolean  "voided",                        default: false
    t.string   "void_reason",       limit: 255
    t.integer  "voided_by",         limit: 4
    t.datetime "created_at",                                    null: false
    t.datetime "updated_at",                                    null: false
  end

  add_index "general_inventories", ["gn_identifier"], name: "index_general_inventories_on_gn_identifier", using: :btree

  create_table "issues", primary_key: "issue_id", force: :cascade do |t|
    t.integer  "inventory_id", limit: 4
    t.integer  "location_id",  limit: 4
    t.integer  "issued_to",    limit: 4
    t.integer  "quantity",     limit: 4
    t.datetime "issue_date"
    t.integer  "issued_by",    limit: 4
    t.boolean  "voided",                 default: false
    t.datetime "created_at",                             null: false
    t.datetime "updated_at",                             null: false
  end

  create_table "location", primary_key: "location_id", force: :cascade do |t|
    t.string   "name",              limit: 255,                 null: false
    t.string   "description",       limit: 255
    t.string   "address1",          limit: 255
    t.string   "address2",          limit: 255
    t.string   "city_village",      limit: 255
    t.string   "state_province",    limit: 255
    t.string   "country",           limit: 255
    t.string   "postal_code",       limit: 255
    t.boolean  "voided",                        default: false
    t.integer  "creator",           limit: 4
    t.datetime "date_created"
    t.integer  "changed_by",        limit: 4
    t.datetime "date_changed"
    t.string   "uuid",              limit: 255
    t.string   "neighborhood_cell", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "location", ["name"], name: "index_location_on_name", using: :btree

  create_table "location_tag", primary_key: "location_tag_id", force: :cascade do |t|
    t.string   "name",          limit: 255,                   null: false
    t.text     "description",   limit: 65535
    t.boolean  "retired",                     default: false
    t.integer  "creator",       limit: 4
    t.datetime "date_created"
    t.integer  "retired_by",    limit: 4
    t.datetime "date_retired"
    t.string   "retire_reason", limit: 255
    t.string   "uuid",          limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "location_tag", ["name"], name: "index_location_tag_on_name", using: :btree

  create_table "location_tag_map", id: false, force: :cascade do |t|
    t.integer  "location_tag_id", limit: 4, null: false
    t.integer  "location_id",     limit: 4, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "location_tag_map", ["location_tag_id", "location_id"], name: "index_location_tag_map_on_location_tag_id_and_location_id", unique: true, using: :btree

  create_table "mobile_visit", force: :cascade do |t|
    t.date     "visit_date",                                     null: false
    t.integer  "visit_supervisor", limit: 4,                     null: false
    t.text     "notes",            limit: 65535
    t.boolean  "voided",                         default: false
    t.integer  "creator",          limit: 4
    t.datetime "date_created"
    t.integer  "changed_by",       limit: 4
    t.datetime "date_changed"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "mobile_visit", ["visit_supervisor"], name: "index_mobile_visit_on_visit_supervisor", using: :btree

  create_table "mobile_visit_products", primary_key: "mvp_id", force: :cascade do |t|
    t.integer  "mobile_visit_id", limit: 4
    t.string   "gn_identifier",   limit: 255
    t.integer  "amount_taken",    limit: 4
    t.integer  "amount_used",     limit: 4
    t.boolean  "voided",                      default: false
    t.datetime "created_at",                                  null: false
    t.datetime "updated_at",                                  null: false
  end

  create_table "mobile_visits", primary_key: "mobile_visit_id", force: :cascade do |t|
    t.date     "visit_date"
    t.integer  "visit_supervisor", limit: 4
    t.boolean  "voided",                     default: false
    t.datetime "created_at",                                 null: false
    t.datetime "updated_at",                                 null: false
  end

  create_table "patient", force: :cascade do |t|
    t.integer  "person_id",               limit: 4,                 null: false
    t.boolean  "voided",                            default: false
    t.integer  "creator",                 limit: 4
    t.datetime "date_created"
    t.integer  "changed_by",              limit: 4
    t.datetime "date_changed"
    t.boolean  "dead",                              default: false
    t.datetime "death_date"
    t.integer  "cause_of_death",          limit: 4
    t.boolean  "patient_id_card_printed",           default: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "patient", ["person_id"], name: "index_patient_on_person_id", using: :btree

  create_table "patient_identifier", force: :cascade do |t|
    t.integer  "patient_id",      limit: 4,                   null: false
    t.integer  "identifier_type", limit: 4,                   null: false
    t.string   "identifier",      limit: 255,                 null: false
    t.boolean  "preferred",                   default: false
    t.boolean  "voided",                      default: false
    t.integer  "creator",         limit: 4
    t.datetime "date_created"
    t.integer  "changed_by",      limit: 4
    t.datetime "date_changed"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "patient_identifier", ["identifier_type"], name: "index_patient_identifier_on_identifier_type", using: :btree
  add_index "patient_identifier", ["patient_id", "identifier_type"], name: "index_patient_identifier_on_patient_id_and_identifier_type", unique: true, using: :btree
  add_index "patient_identifier", ["patient_id"], name: "index_patient_identifier_on_patient_id", using: :btree

  create_table "patient_identifier_type", primary_key: "patient_identifier_type_id", force: :cascade do |t|
    t.string   "name",          limit: 255,                   null: false
    t.text     "description",   limit: 65535
    t.boolean  "retired",                     default: false
    t.integer  "creator",       limit: 4
    t.datetime "date_created"
    t.integer  "retired_by",    limit: 4
    t.datetime "date_retired"
    t.string   "retire_reason", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "person", primary_key: "person_id", force: :cascade do |t|
    t.boolean  "voided",                          default: false
    t.integer  "creator",             limit: 4
    t.datetime "date_created"
    t.integer  "changed_by",          limit: 4
    t.datetime "date_changed"
    t.boolean  "dead",                            default: false
    t.date     "birthdate"
    t.boolean  "birthdate_estimated",             default: false
    t.date     "death_date"
    t.integer  "cause_of_death",      limit: 4
    t.integer  "gender",              limit: 4
    t.string   "gender_string",       limit: 255
    t.integer  "death_reason",        limit: 4
    t.integer  "death_place",         limit: 4
    t.string   "death_place_other",   limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "person_address", primary_key: "person_address_id", force: :cascade do |t|
    t.integer  "person_id",      limit: 4,                   null: false
    t.string   "address1",       limit: 255
    t.string   "address2",       limit: 255
    t.string   "address3",       limit: 255
    t.string   "city_village",   limit: 255
    t.string   "state_province", limit: 255
    t.string   "country",        limit: 255
    t.string   "postal_code",    limit: 255
    t.boolean  "preferred",                  default: false
    t.boolean  "voided",                     default: false
    t.integer  "creator",        limit: 4
    t.datetime "date_created"
    t.integer  "changed_by",     limit: 4
    t.datetime "date_changed"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "person_address", ["person_id"], name: "index_person_address_on_person_id", using: :btree

  create_table "person_attribute", primary_key: "person_attribute_id", force: :cascade do |t|
    t.integer  "person_id",                limit: 4,                     null: false
    t.integer  "person_attribute_type_id", limit: 4,                     null: false
    t.text     "value",                    limit: 65535
    t.integer  "creator",                  limit: 4
    t.datetime "date_created"
    t.boolean  "voided",                                 default: false
    t.integer  "voided_by",                limit: 4
    t.datetime "date_voided"
    t.string   "void_reason",              limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "person_attribute", ["person_attribute_type_id"], name: "index_person_attribute_on_person_attribute_type_id", using: :btree
  add_index "person_attribute", ["person_id"], name: "index_person_attribute_on_person_id", using: :btree

  create_table "person_attribute_type", primary_key: "person_attribute_type_id", force: :cascade do |t|
    t.string   "name",          limit: 255,                   null: false
    t.text     "description",   limit: 65535
    t.boolean  "retired",                     default: false
    t.integer  "retired_by",    limit: 4
    t.datetime "date_retired"
    t.string   "retire_reason", limit: 255
    t.integer  "creator",       limit: 4
    t.datetime "date_created"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "person_name", primary_key: "person_name_id", force: :cascade do |t|
    t.integer  "person_id",          limit: 4,                   null: false
    t.string   "given_name",         limit: 255
    t.string   "middle_name",        limit: 255
    t.string   "family_name",        limit: 255
    t.string   "family_name2",       limit: 255
    t.string   "family_name_suffix", limit: 255
    t.boolean  "preferred",                      default: false
    t.boolean  "voided",                         default: false
    t.integer  "creator",            limit: 4
    t.datetime "date_created"
    t.integer  "changed_by",         limit: 4
    t.datetime "date_changed"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "person_name", ["person_id"], name: "index_person_name_on_person_id", using: :btree

  create_table "person_name_code", primary_key: "person_name_code_id", force: :cascade do |t|
    t.integer  "person_name_id",          limit: 4,   null: false
    t.string   "given_name_code",         limit: 255
    t.string   "middle_name_code",        limit: 255
    t.string   "family_name_code",        limit: 255
    t.string   "family_name2_code",       limit: 255
    t.string   "family_name_suffix_code", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "person_name_code", ["person_name_id"], name: "index_person_name_code_on_person_name_id", using: :btree

  create_table "prescriptions", primary_key: "rx_id", force: :cascade do |t|
    t.integer  "patient_id",       limit: 4
    t.integer  "drug_id",          limit: 4
    t.datetime "date_prescribed"
    t.integer  "quantity",         limit: 4
    t.integer  "amount_dispensed", limit: 4
    t.string   "directions",       limit: 255
    t.integer  "provider_id",      limit: 4
    t.boolean  "voided",                       default: false
    t.datetime "created_at",                                   null: false
    t.datetime "updated_at",                                   null: false
  end

  create_table "role", primary_key: "role", force: :cascade do |t|
    t.string   "description",  limit: 255
    t.integer  "creator",      limit: 4
    t.datetime "date_created"
    t.boolean  "voided",                   default: false
  end

  create_table "user_property", id: false, force: :cascade do |t|
    t.integer  "user_id",        limit: 4,                     null: false
    t.string   "property",       limit: 255,                   null: false
    t.text     "property_value", limit: 65535
    t.integer  "creator",        limit: 4
    t.datetime "date_created"
    t.boolean  "voided",                       default: false
  end

  add_index "user_property", ["user_id", "property"], name: "index_user_property_on_user_id_and_property", unique: true, using: :btree
  add_index "user_property", ["user_id"], name: "index_user_property_on_user_id", using: :btree

  create_table "user_role", id: false, force: :cascade do |t|
    t.integer  "user_id",      limit: 4,                   null: false
    t.string   "role",         limit: 255,                 null: false
    t.integer  "creator",      limit: 4
    t.datetime "date_created"
    t.boolean  "voided",                   default: false
  end

  add_index "user_role", ["role"], name: "index_user_role_on_role", using: :btree
  add_index "user_role", ["user_id", "role"], name: "index_user_role_on_user_id_and_role", unique: true, using: :btree
  add_index "user_role", ["user_id"], name: "index_user_role_on_user_id", using: :btree

  create_table "users", primary_key: "user_id", force: :cascade do |t|
    t.integer  "person_id",     limit: 4
    t.string   "username",      limit: 255,                 null: false
    t.string   "password",      limit: 255,                 null: false
    t.string   "salt",          limit: 255
    t.boolean  "voided",                    default: false
    t.integer  "creator",       limit: 4
    t.datetime "date_created"
    t.datetime "date_changed"
    t.integer  "changed_by",    limit: 4
    t.boolean  "retired",                   default: false
    t.integer  "retired_by",    limit: 4
    t.datetime "date_retired"
    t.string   "retire_reason", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "users", ["person_id"], name: "index_users_on_person_id", using: :btree
  add_index "users", ["username"], name: "index_users_on_username", unique: true, using: :btree

end
