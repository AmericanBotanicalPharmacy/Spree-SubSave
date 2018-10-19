module Spree
  module Admin
    class SubSavesController < ResourceController
      helper Spree::Api::ApiHelpers
      before_action :strip_search_query_params, only: :index

      def index
        params[:q] ||= {}
        @show_only_active = params[:q][:state_eq] == 'active'
        params[:q].delete(:state_eq) unless @show_only_active

        @search = Spree::SubSave.includes(:user, :parent_order).ransack(params[:q])
        @sub_saves = @search.result
                           .page(params[:page])
                           .per(params[:per_page] || Spree::Config[:admin_sub_saves_per_page])
                           .order(created_at: :desc)
      end

      def edit
        return if @sub_save.ship_address_id.present?
        @default_country_id = Address.default.country.id
        @sub_save.ship_address = Spree::Address.new(country_id: @default_country_id)
      end

      # rubocop:disable Metrics/MethodLength
      def create
        invoke_callbacks(:create, :before)
        first_name, last_name = Spree::User::DEFAULT_GUEST_NAME.split(' ')
        user = Spree::User.find_by(email: permitted_resource_params[:email]) ||
          Spree::User.create!(
            email: permitted_resource_params[:email],
            first_name: first_name,
            last_name: last_name,
            password: SecureRandom.hex
          )

        @object.attributes = permitted_resource_params.merge(
          {
            user_id: user&.id,
            state: 'inactive',
            credit_card_id: user&.credit_cards&.default&.first&.id,
            channel: 'phone'
          }
        )

        @object.ship_address = Spree::Address.new(user.default_ship_address.attributes_for_clone) if
          user&.default_ship_address.present?

        if @object.save
          invoke_callbacks(:create, :after)
          flash[:success] = flash_message_for(@object, :successfully_created)
          respond_with(@object) do |format|
            format.html { redirect_to edit_admin_sub_save_url(@object) }
            format.js   { render layout: false }
          end
        else
          invoke_callbacks(:create, :fails)
          respond_with(@object) do |format|
            format.html { render action: :new }
            format.js { render layout: false }
          end
        end
      end
      # rubocop:enable Metrics/MethodLength

      def show
        redirect_to edit_object_url(@object)
      end

      # rubocop:disable Metrics/MethodLength
      def update

        start_date = permitted_resource_params['start_date']
        ship_address_attributes = permitted_resource_params['ship_address_attributes']

        invoke_callbacks(:update, :before)
        change_from = @object.start_date if start_date.present?
        if ship_address_attributes.present?
          ship_address_object_from = @object.ship_address
          diff_attributes_count = 0

          if ship_address_object_from.present?
            ship_address_attributes.each do |k, v|
              break diff_attributes_count += 1 if ship_address_object_from[k.to_sym].to_s != v
            end
            change_from = format_address(ship_address_object_from) if diff_attributes_count.positive?
          else
            diff_attributes_count += 1
            change_from = nil
          end
        end

        if @object.update_attributes(permitted_resource_params)
          if permitted_resource_params['start_date'].present?
            change_to = Date.parse(start_date)
            @object.activity_changed(try_spree_current_user.id, 'changed start date', nil, change_from, change_to) if
              change_from != change_to
          elsif ship_address_attributes.present? && diff_attributes_count.positive?
            change_to = format_address(@object.ship_address)
            @object.activity_changed(try_spree_current_user.id, 'changed shipping address', @object.ship_address,
                                     change_from, change_to)
          end
          invoke_callbacks(:update, :after)
          respond_with(@object) do |format|
            format.html do
              flash[:success] = flash_message_for(@object, :successfully_updated)
              redirect_to edit_object_url(@object)
            end
            format.js { render layout: false }
          end
        else
          invoke_callbacks(:update, :fails)
          respond_with(@object) do |format|
            format.html { render action: :edit }
            format.js { render layout: false }
          end
        end
      end
      # rubocop:enable Metrics/MethodLength

      def change_notes
        permitted_params = params.require(:sub_save).permit(:notes)
        if @object.update_attributes(permitted_params)
          redirect_to edit_admin_sub_save_url(@object)
        else
          @default_country_id = Address.default.country.id
          @sub_save.ship_address = Spree::Address.new(country_id: @default_country_id)
          render action: :edit
        end
      end

      def credit_cards; end

      def orders
        @orders = @object.orders_include_parent
                    .page(params[:page]).per(params[:per_page]).order(created_at: :desc)
      end

      # rubocop:disable Metrics/MethodLength
      # rubocop:disable Metrics/LineLength
      def credit_cards_update
        message_collection = []

        if params['credit_card_id'] == 'new'
          merge_params = { user_id: @sub_save.user_id }
          if params[:sfmc_use_shipping] == '1'
            merge_params = merge_params.merge(
              { bill_address_attributes: @sub_save.ship_address.attributes_for_clone }
            )
          end
          credit_card = Spree::CreditCard.new(credit_card_params.merge(merge_params))
          credit_card.skip_verification_value = true

          change_from = @sub_save.credit_card_id.present? ? "#{@sub_save.credit_card.display_number}(#{@sub_save.credit_card.bill_address.full_display})" : nil

          if credit_card.create_profile_and_save
            @sub_save.update(credit_card_id: credit_card.id)
            change_to = "#{@sub_save.credit_card.display_number}(#{@sub_save.credit_card.bill_address.full_display})"
            @sub_save.activity_changed(
              try_spree_current_user.id,
              'use new credit card',
              @object.credit_card,
              change_from,
              change_to
            )
            message_collection.push(:success, 'updated successfully')
          else
            message_collection.push(:error, credit_card.errors.full_messages.join('<br>'))
          end
        else
          change_from_id = @sub_save.credit_card_id
          change_from = if @sub_save.credit_card.present? && @sub_save.credit_card.bill_address.present?
                          "#{@sub_save.credit_card.display_number}(#{@sub_save.credit_card.bill_address.full_display})"
                        else
                          nil
                        end
          @sub_save.update(credit_card_id: params['credit_card_id'])
          if change_from_id != @sub_save.credit_card_id
            change_to = "#{@sub_save.credit_card.display_number}(#{@sub_save.credit_card.bill_address.full_display})"
            @sub_save.activity_changed(
              try_spree_current_user.id,
              'use another existing credit card',
              @object.credit_card,
              change_from,
              change_to
            )
          end
          message_collection.push(:success, 'updated successfully')
        end

        if request.xhr?
          @message = message_collection
        else
          flash[message_collection.first] = message_collection.last
        end

        respond_to do |format|
          format.js { render 'message' }
          format.html { redirect_to credit_cards_admin_sub_save_path(@sub_save) }
        end
      end
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/LineLength

      def create_shipment
        order = @object.generate_next_order
        flash[:error] = order.errors.full_messages.join(' ') if order.errors.present?

        redirect_back(fallback_location: orders_admin_sub_save_path(@object))
      end

      # rubocop:disable Metrics/MethodLength
      def change_state
        event = [:cancel, :enable].detect { |e| e == params[:event].to_s.to_sym }
        unless event
          flash[:error] = 'Invalid action.'
          return redirect_back(fallback_location: admin_sub_saves_url)
        end

        change_from = @object.state
        success = @object.send event
        if success
          flash[:success] = 'Successfully updated.'
          change_to = @object.state
          @object.activity_changed(try_spree_current_user.id, 'changed SFMC membership state', @object,
                                   change_from, change_to)
        else
          flash[:error] = @object.errors.full_messages.join('. ')
        end
        redirect_back fallback_location: admin_sub_saves_url
      end
      # rubocop:enable Metrics/MethodLength

      def activities
        @activities = @sub_save.activities.includes(:user).order(created_at: :desc)
      end

      private
      def credit_card_params
        params.require(:credit_card).permit(permitted_credit_card_attributes)
      end

      def permitted_credit_card_attributes
        # permitted_source_attributes
        Spree::Api::ApiHelpers.creditcard_attributes + [
          :number,
          :verification_value,
          :expiry,
          bill_address_attributes: permitted_address_attributes - [:id]
        ]
      end

      # rubocop:disable Metrics/LineLength
      def format_address(address)
        return nil if address.blank?
        "#{address.full_name}<br/>#{address.address1} #{address.address2}<br>#{address.city} #{address.state.name} #{address.zipcode} #{address.country.name}<br> #{address.phone}"
      end
      # rubocop:enable Metrics/LineLength
    end
  end
end
