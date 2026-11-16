require 'test_helper'
require_relative '../support/pack_dispensing_records'

class DispensationControllerTest < ActionController::TestCase
  self.fixture_table_names = []
  include PackDispensingRecords

  setup do
    create_pack_records
    session[:user_id] = @user.id
    session[:patient_id] = @patient.id
    session[:location] = 1
  end
  teardown { User.current = nil }

  test 'posting a prepared pack marks its label without taking loose stock' do
    post :create, params: { bottle_id: @label.label_identifier }

    assert_response :success
    assert @label.reload.dispensed?
    assert_equal @label.id, Dispensation.last.prepack_label_id
    assert_equal 0, @bottle.reload.current_quantity
  end

  test 'posting the same pack twice does not dispense it twice' do
    post :create, params: { bottle_id: @label.label_identifier }
    assert_no_difference ['Prescription.count', 'Dispensation.count'] do
      post :create, params: { bottle_id: @label.label_identifier }
    end
    assert_redirected_to '/'
    assert_match(/already been dispensed/, flash[:errors])
  end

  test 'reversal endpoint records the selected reason and releases the exact pack' do
    dispensation = dispense_pack
    post :reverse, params: { id: dispensation.id, reason: 'wrong_pack', notes: 'Wrong label' }, format: :json

    assert_response :success
    assert JSON.parse(response.body)['success']
    assert_equal 'wrong_pack', dispensation.reload.reversal_reason
    assert_equal @user.id, dispensation.reversed_by_id
    assert_not @label.reload.dispensed?
    assert_equal 0, @bottle.reload.current_quantity
  end

  test 'reversal endpoint rejects a second reversal' do
    dispensation = dispense_pack
    2.times { post :reverse, params: { id: dispensation.id, reason: 'wrong_pack' }, format: :json }

    assert_response :conflict
    assert_equal 0, @bottle.reload.current_quantity
    assert_equal 0, dispensation.prescription.reload.amount_dispensed
  end

  test 'reversal endpoint rejects missing reasons and cross-location requests' do
    dispensation = dispense_pack
    post :reverse, params: { id: dispensation.id }, format: :json
    assert_response :unprocessable_entity
    session[:location] = 2
    post :reverse, params: { id: dispensation.id, reason: 'wrong_pack' }, format: :json
    assert_response :unprocessable_entity
    assert @label.reload.dispensed?
  end

  test 'legacy GET void URL cannot change inventory' do
    dispensation = dispense_pack
    get :destroy, params: { id: dispensation.id }

    assert_redirected_to patient_path(@patient.id)
    assert_not dispensation.reload.voided?
    assert @label.reload.dispensed?
  end

  test 'DELETE without a reversal reason cannot bypass the reversal service' do
    dispensation = dispense_pack
    delete :destroy, params: { id: dispensation.id }, format: :json

    assert_response :unprocessable_entity
    assert_not dispensation.reload.voided?
  end

  test 'history keeps reversed entries but removes their reversal controls' do
    dispensation = dispense_pack
    DispensationReversal.call(dispensation_id: dispensation.id, reason: 'wrong_pack', user: @user, location_id: 1)
    @controller.instance_variable_set(:@history, [dispensation.reload])
    html = @controller.view_context.render(partial: 'patients/dispense_view')

    assert_includes html, 'Reversed'
    assert_includes html, 'Wrong pack'
    assert_includes html, @label.label_identifier
    assert_not_includes html, 'openReversalModal(this)'
  end

  test 'active history connects the modal to the POST reversal route' do
    dispensation = dispense_pack
    @controller.instance_variable_set(:@history, [dispensation])
    html = @controller.view_context.render(partial: 'patients/dispense_view')

    assert_includes html, "data-reversal-url=\"#{reverse_dispensation_path(dispensation)}\""
    assert_includes html, 'openReversalModal(this)'
    assert_routing({ path: reverse_dispensation_path(dispensation), method: :post },
                   controller: 'dispensation', action: 'reverse', id: dispensation.id.to_s)
  end

  test 'reversal requests require a CSRF token when forgery protection is enabled' do
    dispensation = dispense_pack
    @controller.allow_forgery_protection = true

    assert_raises(ActionController::InvalidAuthenticityToken) do
      post :reverse, params: { id: dispensation.id, reason: 'wrong_pack' }, format: :json
    end
    assert_not dispensation.reload.voided?
    assert @label.reload.dispensed?
  ensure
    @controller.allow_forgery_protection = false
  end

  test 'historical entries show both disabled controls with a reconciliation explanation' do
    historical = Dispensation.new(patient_id: @patient.id, inventory_id: @bottle.id,
                                   quantity: 10, dispensation_date: Time.current)
    historical.save!(validate: false)
    @controller.instance_variable_set(:@history, [historical])
    html = @controller.view_context.render(partial: 'patients/dispense_view')
    controls = Nokogiri::HTML.fragment(html).css('button.dispensation-icon-button[disabled]')

    assert_equal 2, controls.size
    assert_equal ['Void Item', 'Reverse'], controls.map { |control| control['aria-label'] }
    assert_includes html, 'Reversal requires reconciliation'
  end

  test 'dispensation report includes both controls and the reversal modal' do
    @controller.allow_forgery_protection = true
    dispensation = dispense_pack
    @controller.instance_variable_set(:@records, [dispensation])
    @controller.instance_variable_set(:@report_type, 'Dispensed packs')
    html = dispensation.stub(:dispensed_by_name, 'Test dispenser') do
      @controller.view_context.render(template: 'dispensation/list', layout: 'layouts/application')
    end
    document = Nokogiri::HTML.fragment(html)

    assert_equal 2, document.css('button.dispensation-icon-button:not([disabled])').size
    assert_equal 1, document.css('#reversalModal').size
    assert_equal 1, document.css('meta[name="csrf-token"]').size
    assert_equal 7, document.css('#dispensationTable thead th').size
    assert_includes html, reverse_dispensation_path(dispensation)
  ensure
    @controller.allow_forgery_protection = false
  end

  test 'pack summaries link to all linked dispensations even when dispensed before today' do
    dispensation = dispense_pack
    dispensation.update!(dispensation_date: 2.days.ago)
    @controller.stub(:render, nil) do
      get :list, params: { prepack_id: @prepack.id }
    end

    records = @controller.instance_variable_get(:@records)
    assert_equal [dispensation.id], records.pluck(:dispensation_id)
    assert_equal "/dispensation/list?prepack_id=#{@prepack.id}",
                 list_dispensation_index_path(prepack_id: @prepack.id)
  end

  test 'expired entries disable both controls and cannot bypass the deadline by POST' do
    dispensation = dispense_pack
    travel_to(dispensation.dispensation_date + 24.hours)
    @controller.instance_variable_set(:@history, [dispensation])
    html = @controller.view_context.render(partial: 'patients/dispense_view')
    document = Nokogiri::HTML.fragment(html)

    assert_equal 2, document.css('button.dispensation-icon-button[disabled]').size
    assert_includes html, '24-hour reversal window has expired'
    post :reverse, params: { id: dispensation.id, reason: 'wrong_pack' }, format: :json
    assert_response :unprocessable_entity
    assert_not dispensation.reload.voided?
    assert @label.reload.dispensed?
  end
end
