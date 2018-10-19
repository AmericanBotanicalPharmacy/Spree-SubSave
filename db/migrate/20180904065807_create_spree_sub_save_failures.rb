class CreateSpreeSubSaveFailures < ActiveRecord::Migration[5.0]
  def change
    create_table :spree_sub_save_failures do |t|
      t.string :state
      t.text :error_messages
      t.integer :related_order_id, index: true
      t.integer :sub_save_id, index: true

      t.timestamps
    end
  end
end
