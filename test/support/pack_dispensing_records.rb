module PackDispensingRecords
  def create_pack_records
    @user = User.new(username: "pack_user_#{SecureRandom.hex(4)}",
                     password: 'stored-password', salt: 'existing-salt')
    @user.save!(validate: false)
    User.current = @user
    @patient = EdimPatient.create!(full_name: 'Pack Test Patient')
    @drug = Drug.create!(name: 'Test medication', dose_form: 'Tablet')
    @bottle = GeneralInventory.create!(
      drug: @drug, expiration_date: Date.current + 30, date_received: Date.current,
      received_quantity: 20, current_quantity: 0, location_id: 1
    )
    @prepack = Prepack.create!(
      bottle: @bottle, drug: @drug, prepacked_by: @user, location_id: 1,
      quantity_per_pack: 10, num_packs: 2, total_quantity: 20, current_num_packs: 2,
      directions: 'Take one daily', times: ['morning'].to_json, pack_identifier: SecureRandom.uuid
    )
    @label = PrepackLabel.create!(prepack: @prepack, bottle: @bottle,
                                 label_identifier: "PK-#{SecureRandom.hex(4)}-1")
    @other_label = PrepackLabel.create!(prepack: @prepack, bottle: @bottle,
                                       label_identifier: "PK-#{SecureRandom.hex(4)}-2")
  end

  def dispense_pack(label = @label, **overrides)
    PackDispensation.call(**{
      label_identifier: label.label_identifier, patient_id: @patient.id,
      user: @user, location_id: @prepack.location_id
    }.merge(overrides))
  end
end
