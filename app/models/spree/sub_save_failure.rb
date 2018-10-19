module Spree
  class SubSaveFailure < ApplicationRecord
    belongs_to :sub_save
    alias membership sub_save

    include Spree::Subscription::OrderFailure
  end
end
