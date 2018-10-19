module Spree
  class SubSave < ApplicationRecord
    include Spree::Core::NumberGenerator.new(prefix: 'SS', length: 9)
    has_many :sub_save_items, dependent: :destroy, inverse_of: :sub_save
    alias line_items sub_save_items

    has_many :orders, dependent: :restrict_with_error, inverse_of: :sub_save
    has_many :sub_save_failures, dependent: :destroy
    alias failures sub_save_failures

    include Spree::Subscription::Membership

    def active_failures
      failures.with_state(:active)
    end
  end
end
