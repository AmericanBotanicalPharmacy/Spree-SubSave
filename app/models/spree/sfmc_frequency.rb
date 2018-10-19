module Spree
  class SFMCFrequency < Spree::Base
    validates :name, presence: true, uniqueness: true
    validate :frequency_must_be_valid

    scope :active, -> { where(active: true) }

    def self.one_time_frequency_id
      where('frequency like ?', '%0:month%').select(:id).take&.id
    end

    def self.monthly_frequency
      find_by('frequency like ?', '%1:month%')
    end

    def frequency_in_time
      number, unit = unit_and_number
      number.send unit # => 1.month/45.day
    end

    def unit_and_number
      number, unit = frequency[/\d+\:\w+/].split(':')
      [number.to_i, unit]
    end

    def in_multiple_periods(count)
      number, unit = unit_and_number
      (number * count).send(unit)
    end

    private

    def frequency_must_be_valid
      frequency_in_time.from_now
    rescue NoMethodError
      errors.add(:base, 'Frequency is not defined properly, unit can only be month or day.')
    end
  end
end
