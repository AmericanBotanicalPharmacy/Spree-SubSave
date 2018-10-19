module Spree::Subscription::OrderFailure
  extend ActiveSupport::Concern

  included do
    serialize :error_messages, Array
    belongs_to :related_order, class_name: 'Spree::Order'

    validates :related_order_id, uniqueness: true, allow_nil: true

    state_machine :state, initial: :active do
      event :resolve do
        transition to: :resolved, from: :active
      end

      event :activate do
        transition to: :active, from: :resolved
      end
    end

    scope :active, -> { with_state(:active) }
  end

  class_methods do
    # rubocop:disable Metrics/MethodLength
    def to_csv(options = {})
      CSV.generate(options) do |csv|
        headers = [
          'Number',
          'Email',
          'Phone',
          'Error',
          'Related Order Number',
          'Order Failed At',
          'Ship Address'
        ]

        csv << headers
        find_each do |failure|
          values = [
            failure.membership.number,
            failure.membership.email,
            failure.membership.phone,
            failure.error_messages.join(', '),
            failure.related_order&.number,
            failure.friendly_created_at,
            failure.membership.ship_address&.full_display
          ]

          csv << values
        end
      end
    end
    # rubocop:enable Metrics/MethodLength
  end

  def friendly_created_at
    [I18n.l(created_at.to_date), created_at.strftime('%l:%M %p').strip].join(' ')
  end
end
