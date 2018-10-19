class GenerateOrderFromSubSaveWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'sub_save_program', retry: false

  def perform(sub_save_id, order_date = Date.current)
    Rails.logger.info("[SubSave] Start to generate order for SubSave #{sub_save_id}")
    sub_save = Spree::SubSave.find(sub_save_id)

    order = sub_save.generate_order_for_date(order_date)

    if order.completed?
      Rails.logger.info("SubSave order generated completed with number #{order.number}")
    else
      handle_failure(sub_save, order)
    end
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error("SubSave not found with id #{sub_save_id}")
  end

  private

  def handle_failure(sub_save, order)
    Rails.logger.error("SubSave order error #{order.errors.full_messages.join(' ')} with number #{order.number}")

    Spree::SubSaveFailure.create!(
      sub_save: sub_save,
      related_order: order,
      error_messages: order.errors.full_messages
    )
  end
end
