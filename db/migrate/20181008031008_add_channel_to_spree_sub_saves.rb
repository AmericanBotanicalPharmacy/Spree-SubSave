class AddChannelToSpreeSubSaves < ActiveRecord::Migration[5.0]
  def change
    add_column :spree_sub_saves, :channel, :string, default: 'phone'
  end
end
