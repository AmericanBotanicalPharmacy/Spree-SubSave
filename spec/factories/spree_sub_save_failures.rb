FactoryGirl.define do
  factory :spree_sub_save_failure, class: 'Spree::SubSaveFailure' do
    state "MyString"
    error_messages "MyText"
    related_order_id 1
    sub_save nil
  end
end
