class CreateSpreeSubSaves < ActiveRecord::Migration[5.0]
  def change
    create_table :spree_sub_saves do |t|
      t.date :start_date
      t.integer :credit_card_id
      t.integer :parent_order_id
      t.integer :ship_address_id
      t.string :email
      t.string :number, index: true, unique: true
      t.string :state
      t.text :notes,           limit: 65535

      t.references :user

      t.timestamps
    end

    add_column :spree_orders, :sub_save_id, :integer
  end
end
