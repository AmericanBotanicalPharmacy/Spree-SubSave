module Spree::Subscription::Membership
  extend ActiveSupport::Concern

  included do
    belongs_to :ship_address, foreign_key: :ship_address_id, class_name: 'Spree::Address'
    belongs_to :parent_order, class_name: 'Spree::Order'
    belongs_to :user
    belongs_to :credit_card
    has_many :activities, as: :activityable

    accepts_nested_attributes_for :ship_address

    validates :email, presence: true, email: true
    validates_uniqueness_of :parent_order_id, allow_blank: true
    validate :ensure_effective_start_date, if: :start_date_changed?

    after_save do
      if start_date_changed? || state_changed?
        line_items.active.each(&:reset_next_order_date)
      end
    end

    after_create :sfmc_subscribe

    state_machine :state, initial: :active do
      before_transition to: :active do |membership|
        unless membership.valid_membership?
          membership.errors.add(:base, Spree.t(:invalid_membership_and_check))
          throw :halt
        end
      end

      event :disable do
        transition to: :inactive, from: :active
      end

      event :enable do
        transition to: :active, from: :inactive
      end

      event :cancel do
        transition to: :canceled, from: [:inactive, :active]
      end

      before_transition to: :canceled do |membership|
        membership.canceled_at = Time.current
      end

      after_transition to: :canceled do |membership|
        SFMCSubscribeWorker.perform_in(1.minute, 'unsubscribe', membership.email)
      end
    end

    delegate :bill_address, to: :credit_card
    delegate :email, to: :user, prefix: true, allow_nil: true
    delegate :phone, to: :ship_address, allow_nil: true

    scope :active, -> { where(state: :active) }

    scope :ready_to_generate_order, lambda { |date = Date.tomorrow|
      membership_table_name = table_name
      line_items_table_name = new.line_items.new.class.table_name
      line_items_association_name = new.method(:line_items).original_name

      with_state(:active)
        .joins(line_items_association_name)
        .where("#{membership_table_name}.credit_card_id IS NOT NULL")
        .where("#{membership_table_name}.start_date <= ?", date)
        .where(:"#{line_items_table_name}" => { next_order_date: date })
        .group("#{membership_table_name}.id")
    }

    scope :credit_card_expires_in_3_months, lambda {
      with_state(:active)
        .joins(:credit_card)
        .where("
          DATE_FORMAT(CONCAT(spree_credit_cards.year, '-', spree_credit_cards.month, '-01'), '%Y-%m-%d')
          between DATE_FORMAT(curdate(), '%Y-%m-01')
          and LAST_DAY(DATE_ADD(curdate(), interval 2 month))
        ")
    }

    scope :filter_sensitivity_pattern, lambda { |pattern|
      where.not('email LIKE ?', pattern)
    }
  end

  # Filter the not avaiable and the one time only
  def valid_line_items
    line_items.active
  end

  def allowing_items_changes?
    return true unless last_complete_order&.persisted?
    !last_complete_order.ship_date_or_completed_date.future?
  end

  def complete_orders_include_parent
    orders_include_parent.complete.order(completed_at: :desc)
  end

  def orders_include_parent
    Spree::Order.where(id: [parent_order_id].compact + order_ids)
  end

  def parent_order_date
    @parent_order_date ||= parent_order&.completed_at
    (@parent_order_date || Time.zone.at(0)).to_date # Use Epoch time to consistently return Date object
  end

  # Epoch date is used when a date object is needed in statement
  # otherwsie there will be a lot if/else when comparing dates which one of them could be nil
  def epoch_date
    @epoch_date ||= Time.zone.at(0).to_date
  end

  def last_complete_order
    orders.complete.order(completed_at: :desc).first
  end

  def next_order_date
    line_items.map(&:next_order_date).compact.min
  end

  def generate_next_order
    generate_order_for_date(next_order_date)
  end

  def generate_order_for_date(order_date)
    prepare_order_for_date(order_date)
  end

  def valid_membership?
    start_date && ship_address_id && credit_card_id && line_items.present?
  end

  def ensure_allowing_items_changes
    return true if allowing_items_changes?
    errors.add(:base, Spree.t(:membership_not_allowing_items_changes))
    false
  end

  # rubocop:disable Metrics/MethodLength
  def activity_changed(user_id, name, source, change_from, change_to)
    source_id = source&.id
    source_type = source&.class&.name
    Spree::Activity.create!(
      name: name,
      activityable_type: self.class.name,
      activityable_id: id,
      user_id: user_id,
      source_id: source_id,
      source_type: source_type,
      change_from: change_from,
      change_to: change_to
    )
  end
  # rubocop:enable Metrics/MethodLength

  def update_line_items(order_date, order_id)
    line_items.ready_to_order_on_date(order_date).each do |li|
      li.last_order_id = order_id
      li.increase_one_frequency_and_save!
    end
  end

  private

  # rubocop:disable Metrics/MethodLength
  def prepare_order_for_date(order_date)
    # 1. Add variants to new order
    order = user ? orders.new(user: user, channel: channel) : orders.new(email: email, channel: channel)
    # Set ship_date for order
    order.update(ship_date: order_date)

    unless active?
      order.errors.add(:base, Spree.t(:membership_inactive))
      return order
    end

    unless ship_address.present?
      order.errors.add(:base, Spree.t(:membership_missing_ship_address))
      return order
    end

    unless credit_card.present?
      order.errors.add(:base, Spree.t(:membership_missing_credit_card))
      return order
    end

    order.state_transition_user_id = 0
    items = line_items.ready_to_order_on_date(order_date)

    if items.size.zero?
      order.errors.add(:base, Spree.t(:missing_line_item))
      return order
    end

    items.each do |item|
      order.contents.add(item.variant, item.quantity)
    end

    order.next # go to "address" state

    # 2. Update ship address
    order.update(
      ship_address_attributes: ship_address.attributes_for_clone,
      bill_address_attributes: bill_address.attributes_for_clone
    )

    order.next # go to "delivery" state

    # 3. Apply shipping
    order.refresh_shipment_rates(Spree::ShippingMethod::DISPLAY_ON_BACK_END)
    order.set_shipments_cost

    order.next # go to "payment" state

    handle_payment_for_order(order)

    if order.payments.select(&:valid?).blank?
      order.errors.add(:base, Spree.t(:order_payment_failure))
      return order
    end

    order.next # go to "complete" state
    order
  rescue ActiveRecord::RecordInvalid => e
    order.errors.add(:base, e.message)
    order
  end

  def handle_payment_for_order(order)
    order.send :update_payment_method_from_source, credit_card # try associated cc first
  rescue Spree::Core::GatewayError => e
    first_error = e.message

    if user
      credit_cards = user.credit_cards.saved - [credit_card] # try other ccs from user
      credit_cards.each do |cc|
        next if cc.expired?

        begin
          order.send :update_payment_method_from_source, cc
          next unless (payment = order.payments.valid.first)
          update(credit_card: cc) if cc == payment.source
          break
        rescue Spree::Core::GatewayError => e
          next
        end
      end
    end

    if order.payments.blank?
      order.errors.add(:base, first_error)
      return order
    end
  end

  def ensure_effective_start_date
    errors.add(:base, Spree.t(:start_date_must_in_future)) if start_date && !start_date.future?
  end

  def sfmc_subscribe
    SFMCSubscribeWorker.perform_in(1.minute, 'subscribe', email)
  end
end
