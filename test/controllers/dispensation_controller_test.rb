require 'test_helper'

class DispensationControllerTest < ActionController::TestCase
  test 'prepared pack batch printing includes each original barcode' do
    get :print_dispensation_label, params: { id: "PREPACK-#{@prepack.id}" }

    assert_response :success
    assert_equal 2, response.body.lines.grep(/^B/).size
    assert_includes response.body, ",\"#{@label.label_identifier}\""
    assert_includes response.body, ",\"#{@other_label.label_identifier}\""
    assert_includes response.body, "Pack No : #{@label.label_identifier}"
    assert_includes response.body, "Pack No : #{@other_label.label_identifier}"
  end

  test 'single prepared pack printing retains its barcode' do
    get :print_dispensation_label, params: { id: "PREPACK-#{@prepack.id}", single: '1' }

    assert_response :success
    assert_equal 1, response.body.lines.grep(/^B/).size
    assert_includes response.body, ",\"#{@label.label_identifier}\""
    assert_includes response.body, "Pack No : #{@label.label_identifier}"
  end

  test 'dispensed pack printing uses its exact pack barcode instead of an RX identifier' do
    dispensation = dispense_pack
    get :print_dispensation_label, params: { id: dispensation.rx_id }

    assert_response :success
    assert_equal 1, response.body.lines.grep(/^B/).size
    assert_includes response.body, ",\"#{@label.label_identifier}\""
    assert_includes response.body, "Pack No : #{@label.label_identifier}"
  end

  test 'direct dispensation printing retains the linked pack barcode' do
    dispensation = dispense_pack
    Dispensation.where(dispensation_id: dispensation.id).update_all(dispensation_id: 100_000)
    get :print_dispensation_label, params: { id: 100_000 }

    assert_response :success
    assert_equal 1, response.body.lines.grep(/^B/).size
    assert_includes response.body, ",\"#{@label.label_identifier}\""
    assert_includes response.body, "Pack No : #{@label.label_identifier}"
  end

end
