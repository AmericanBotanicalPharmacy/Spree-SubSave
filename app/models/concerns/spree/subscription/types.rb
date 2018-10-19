module Spree::Subscription::Types
  extend ActiveSupport::Concern

  included do
    enum subscription_type: { sfmc: 0, sub_save: 1 }
  end
end
