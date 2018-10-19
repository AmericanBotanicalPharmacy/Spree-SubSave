module Spree
  module Api
    module V1
      class SubSaves::LineItemsController < Spree::Api::BaseController
        before_action :load_line_item, except: :create

        # rubocop:disable Metrics/MethodLength
        def create
          li = sub_save.line_items.build(
            {
              variant_id: params[:line_item][:variant_id],
              quantity: params[:line_item][:quantity]
            }
          )

          if li.save
            i18n_line_item_changed = Spree.t('sub_save_activities.line_item_changed',
                                             variant_name: li.variant.name,
                                             variant_sku: li.variant.sku)
            name = "added #{i18n_line_item_changed}"
            li.sub_save.activity_changed(
              current_api_user.id,
              name,
              li,
              nil,
              "quantity: #{li.quantity}"
            )

            respond_with(li, default_template: 'spree/api/v1/sub_save_items/show')
          else
            unprocessable_entity(sp.errors.full_messages)
          end
        end

        def update
          diff_attributes_from = []
          diff_attributes_to = []
          line_items_attributes.each do |k, v|
            v = Date.parse(v) if k == 'discontinue_on' && v.present?
            next if @line_item[k.to_sym].to_s == v

            if k == 'sfmc_frequency_id'
              diff_attributes_from << "sfmc_frequency:#{Spree::SFMCFrequency.find_by(id: @line_item[k.to_sym])&.name}"
              diff_attributes_to << "sfmc_frequency:#{Spree::SFMCFrequency.find_by(id: v)&.name}"
            else
              diff_attributes_from << "#{k}:#{@line_item[k.to_sym]}"
              diff_attributes_to << "#{k}:#{v}"
            end

          end

          if @line_item.update(line_items_attributes)
            if diff_attributes_from.present? && diff_attributes_to.present?
              name = "updated #{Spree.t('sub_save_activities.line_item_changed',
                                        variant_name: @line_item.variant.name,
                                        variant_sku: @line_item.variant.sku)}"
              @line_item.sub_save.activity_changed(
                current_api_user.id,
                name,
                @line_item,
                diff_attributes_from.join('<br/>'),
                diff_attributes_to.join('<br/>')
              )
            end
            respond_with(@line_item, default_template: 'spree/api/v1/sfmc_line_items/show')
          else
            invalid_resource!(@line_item)
          end
        end
        # robocop:enable Metrics/MethodLength

        def destroy
          return unless @line_item.destroy!

          name = "deleted #{Spree.t('sub_save_activities.line_item_changed',
                                    variant_name: @line_item.variant.name,
                                    variant_sku: @line_item.variant.sku)}"
          @line_item.sub_save.activity_changed(
            current_api_user.id,
            name,
            @line_item,
            @line_item.quantity,
            nil
          )
          render json: { msg: 'ok' }, status: :ok
        end

        private
        def sub_save
          @sub_save ||= Spree::SubSave.find(params[:sub_save_id])
        end

        def load_line_item
          @line_item = sub_save.line_items.accessible_by(current_ability, :read).find(params[:id])
          authorize! :update, @line_item
        end

        def line_items_attributes
          params.require(:line_item).permit(
            :quantity, :discontinue_on, :sfmc_frequency_id, :start_date
          )
        end
      end
    end
  end
end
