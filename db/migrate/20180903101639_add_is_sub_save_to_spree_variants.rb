class AddIsSubSaveToSpreeVariants < ActiveRecord::Migration[5.0]
  def change
    add_column :spree_variants, :is_sub_save, :boolean, default: false
  end
end
