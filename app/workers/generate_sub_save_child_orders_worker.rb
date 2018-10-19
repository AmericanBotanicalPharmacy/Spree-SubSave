class GenerateSubSaveChildOrdersWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'sub_save_program'

  def perform
    order_date = Date.tomorrow
    Rails.logger.info('Start generate Sub & Save child orders for date #{order_date.to_s}...')

    Spree::SubSave.ready_to_generate_order.find_each do |item|
      GenerateOrderFromSubSaveWorker.perform_in(1.minute, item.id, order_date)
    end
  end
end
