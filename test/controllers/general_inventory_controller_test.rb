require 'test_helper'
require_relative '../support/pack_dispensing_records'

class GeneralInventoryControllerTest < ActionController::TestCase
  self.fixture_table_names = []
  include PackDispensingRecords

  setup do
    create_pack_records
    session[:user_id] = @user.id
    session[:patient_id] = @patient.id
    session[:location] = 1
  end
  teardown { User.current = nil }

  test 'scanning a prepared pack marks its label without taking loose stock' do
    get :ajax_bottle, params: { id: @label.label_identifier, context: 'patient' }

    assert_response :success
    result = JSON.parse(response.body)
    assert result['prepack']
    assert_equal 0, result['currentQty']
    assert_equal @label.id, Dispensation.find(result['dispensation_id']).prepack_label_id
    assert @label.reload.dispensed?
    assert_equal 0, @bottle.reload.current_quantity
  end

  test 'scanning a pack for prepacking only looks it up' do
    assert_no_difference ['Prescription.count', 'Dispensation.count'] do
      get :ajax_bottle, params: { id: @label.label_identifier, context: 'prepacking' }
    end
    assert_response :success
    assert_not @label.reload.dispensed?
  end

  test 'expired scans return an error without dispensing' do
    @bottle.update!(expiration_date: Date.current)
    get :ajax_bottle, params: { id: @label.label_identifier, context: 'patient' }

    assert_response :unprocessable_entity
    assert JSON.parse(response.body)['expired']
    assert_not @label.reload.dispensed?
  end
end
