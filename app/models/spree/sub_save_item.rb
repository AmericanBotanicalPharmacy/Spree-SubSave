module Spree
  class SubSaveItem < ApplicationRecord
    belongs_to :sub_save
    alias membership sub_save
    alias membership= sub_save=

    include Spree::Subscription::LineItem
  end
end
