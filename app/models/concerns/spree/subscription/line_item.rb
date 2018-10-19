module Spree::Subscription::LineItem
  extend ActiveSupport::Concern

  included do
    acts_as_paranoid

    belongs_to :variant
    belongs_to :sfmc_frequency
    belongs_to :last_order, class_name: 'Spree::Order'

    validate :ensure_discontinue_on_in_future, if: :discontinue_on_changed?
    validates :membership, presence: true

    before_save(on: :create, unless: :sfmc_frequency) do
      self.sfmc_frequency = Spree::SFMCFrequency.monthly_frequency
    end

    before_save do
      self.next_order_date = compute_next_order_date if sfmc_frequency_id_changed? || discontinue_on_changed?
    end

    after_commit do
      # Don't try to disable membership if this callback is triggered by sfmc_membership.destroy
      membership.disable if membership.persisted? && !membership.line_items.active.any?
    end

    scope :not_discontinued, -> (date = Date.current) { where(discontinue_on: nil).or(where('discontinue_on > ?', date)) }
    scope :active, lambda {
      not_discontinued.where.not(
        'sfmc_frequency_id = ? AND last_order_id IS NOT NULL',
        Spree::SFMCFrequency.one_time_frequency_id
      ) # not (one-time-only and finished)
    }

    scope :ready_to_order_on_date, lambda { |date|
      not_discontinued(date).where(next_order_date: date).or(
        not_discontinued(date).where(sfmc_frequency_id: Spree::SFMCFrequency.one_time_frequency_id, last_order_id: nil))
    }

    scope :one_time_addon, lambda {
      not_discontinued.where(
        'sfmc_frequency_id = ? AND last_order_id IS NULL',
        Spree::SFMCFrequency.one_time_frequency_id
      )
    }

  end

  def active?
    @active ||= self.class.active.exists?(id: id)
  end

  def active_text
    active? ? 'active' : 'inactive'
  end

  def reset_next_order_date
    update(next_order_date: compute_next_order_date)
  end

  def increase_one_frequency_and_save!
    self.next_order_date += sfmc_frequency.frequency_in_time if next_order_date
    save!
  end

  def one_time_frequency?
    sfmc_frequency_id == Spree::SFMCFrequency.one_time_frequency_id
  end

  def start_date_for_next_order
    membership.start_date
  end

  def compute_next_order_date_without_discontinue_on
    return unless (date = current_date = start_date_for_next_order)

    count = 0
    loop do # ensure next order is in future time
      break date if verify_next_order_date(date)
      break if count > 100 # fail safe in case data error causing infinite loop
      count += 1

      # Note the trap here:
      # Date.parse('2018-01-31') + 1.month + 1.month => 2018-03-28 (BAD)
      # Date.parse('2018-01-31') + 2.month => 2018-03-31 (GOOD)
      date = current_date + sfmc_frequency.in_multiple_periods(count)
    end
  end

  def verify_next_order_date(date)
    date.future?
  end

  def compute_next_order_date
    return if !membership.active? || one_time_frequency?

    next_date = compute_next_order_date_without_discontinue_on
    return unless next_date

    (discontinue_on && discontinue_on <= next_date) ? nil : next_date
  end

  def price
    if sfmc_frequency_id == Spree::SFMCFrequency.one_time_frequency_id
      variant.active_sale_price || variant.original_price
    else
      variant.sfmc_price || variant.active_sale_price || variant.original_price
    end
  end

  private

  def ensure_discontinue_on_in_future
    errors.add(:base, Spree.t(:discontinue_on_must_in_future)) if discontinue_on && !discontinue_on.future?
  end
end
