class CreateSpreeSubSaveItems < ActiveRecord::Migration[5.0]
  def change
    create_table :spree_sub_save_items do |t|
      t.date :discontinue_on
      t.date :next_order_date
      t.datetime :deleted_at
      t.integer :last_order_id
      t.integer :quantity

      t.references :sfmc_frequency
      t.references :sub_save
      t.references :variant

      t.timestamps
    end
  end
end
