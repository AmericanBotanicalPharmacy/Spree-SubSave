module Spree
  module Admin
    class SubSaveFailuresController < ResourceController
      def index
        params[:q] ||= {}
        params[:q][:state_eq] = 'active' unless params[:q].key?(:state_eq) # default to active

        @search = Spree::SubSaveFailure.includes(:sub_save).ransack(search_params)
        @sub_save_failures = @search.result
                                 .page(params[:page])
                                 .per(params[:per_page])
                                 .order(created_at: :desc)
      end

      def resolve
        @object.resolve!
        redirect_back fallback_location: admin_sub_save_failures_url
      end

      def export_active
        @search = Spree::SubSaveFailure.includes(:sub_save).ransack(search_params)

        respond_to do |format|
          format.csv { send_data @search.result.to_csv }
        end
      end

      private

      def search_params
        params[:q] ||= {}
        @search_params = params[:q].is_a?(String) ? Rack::Utils.parse_nested_query(params[:q]) : params[:q]
        @show_only_active = @search_params[:state_eq] == 'active'
        @search_params.delete(:state_eq) unless @show_only_active
        @search_params
      end
    end
  end
end
