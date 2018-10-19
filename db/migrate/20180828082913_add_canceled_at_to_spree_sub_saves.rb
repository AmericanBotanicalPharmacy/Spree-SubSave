class AddCanceledAtToSpreeSubSaves < ActiveRecord::Migration[5.0]
  def change
    add_column :spree_sub_saves, :canceled_at, :datetime
  end
end
