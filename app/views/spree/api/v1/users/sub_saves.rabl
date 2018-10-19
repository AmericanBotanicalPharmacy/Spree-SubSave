object false

child(@sub_saves => :sub_saves) do
  attributes :number, :start_date, :state

  child bill_address: :bill_address do
    extends "spree/api/v1/addresses/show"
  end

  child ship_address: :ship_address do
    extends "spree/api/v1/addresses/show"
  end

  child credit_card: :credit_card do
    extends "spree/api/v1/credit_cards/show"
  end

  child(:valid_line_items => :line_items) do
    attributes :quantity, :sfmc_frequency_id

    node(:sfmc_frequency_name) { |v| v.sfmc_frequency&.name }

    child :variant do
      attributes :product_id, :id, :slug, :name
      attribute available?: :available

      node(:options_text) { |v| v.options_text }

      child(images: :images) do
        Spree::Image.attachment_definitions[:attachment][:styles].each do |k, v|
          node("#{k}_url") { |i| i.attachment.url(k) }
        end
      end
    end
  end
end

if @sub_saves.respond_to?(:total_pages)
  node(:count) { @sub_saves.count }
  node(:current_page) { (params[:page] || 1).to_i }
  node(:pages) { @sub_saves.total_pages }
end
