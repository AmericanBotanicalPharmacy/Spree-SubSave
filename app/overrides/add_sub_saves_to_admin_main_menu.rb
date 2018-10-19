Deface::Override.new(
  virtual_path: 'spree/layouts/admin',
  name: 'sub_saves_admin_sidebar_menu',
  insert_bottom: '#main-sidebar',
  partial: 'spree/admin/shared/sub_save_sidebar_menu'
)
