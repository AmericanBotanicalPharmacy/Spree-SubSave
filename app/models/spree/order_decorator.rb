require 'csv'
module Spree
  Order.class_eval do
    has_one :purchased_sub_save, class_name: 'Spree::SubSave', foreign_key: :parent_order_id,
            dependent: :restrict_with_error, inverse_of: :parent_order
    belongs_to :sub_save

    def sub_save_items?
      line_items.any?(&:sub_save?)
    end

    def generate_purchased_sub_save
      return if purchased_sub_save || valid_credit_cards.blank?

      membership_user = user || Spree::User.find_by(email: email) ||
        Spree::User.create!(
          email: email,
          first_name: ship_address.firstname,
          last_name: ship_address.lastname,
          password: SecureRandom.hex
        )

      sp = build_purchased_sub_save(
        email: email,
        user_id: membership_user.id,
        ship_address: ship_address.clone,
        credit_card_id: valid_credit_cards.first.id,
        channel: channel
      )

      line_items.each do |line_item|
        next unless line_item.sub_save?
        sp.line_items << Spree::SubSaveItem.new(
          variant_id: line_item.variant_id,
          quantity: line_item.quantity,
          sfmc_frequency_id: line_item.sfmc_frequency_id || Spree::SFMCFrequency.monthly_frequency
        )
      end
      sp.save

      return unless sp.persisted?

      sp.start_date = completed_at.to_date
      sp.save(validate: false) # skip start date validation of future date
    end
  end
end
