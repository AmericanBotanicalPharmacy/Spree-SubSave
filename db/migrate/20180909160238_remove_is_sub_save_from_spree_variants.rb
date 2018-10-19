class RemoveIsSubSaveFromSpreeVariants < ActiveRecord::Migration[5.0]
  def change
    remove_column :spree_variants, :is_sub_save, :boolean
  end
end
