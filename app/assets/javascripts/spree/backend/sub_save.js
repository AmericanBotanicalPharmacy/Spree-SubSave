$(document).ready(function() {
  $('div[data-hook="admin_sub_save_edit_form"]').find('.toggle-active-items').click(function(e){
    var el = e.currentTarget
    if (el.dataset.state == 'active-only') {
      el.dataset.state = 'show-all'
      el.textContent = 'Show Only Active'
      $(el.dataset.target).find('tr').removeClass('hidden');
    } else {
      el.dataset.state = 'active-only'
      el.textContent = 'Show All'
      $(el.dataset.target).find('tr[data-state="inactive"]').addClass('hidden');
    }
  })

  $('input[name="sfmc_use_shipping"]').on('change', function() {
    if (this.checked) {
      $('#sfmc_billing').hide();
    } else {
      $('#sfmc_billing').show();
    }
  });

  $('a.edit-sub-save-line-item').click(function(event) {
    event.preventDefault()
    toggleLineItemEdit(event.currentTarget)
  });
  $('a.cancel-sub-save-line-item').click(function(event) {
    event.preventDefault()
    toggleLineItemEdit(event.currentTarget)
  });

  $('a.save-sub-save-line-item').click(function(event) {
    event.preventDefault();

    var save = $(this);
    var id = save.data('sub-save-line-item-id');
    var quantity = parseInt(save.parents('tr').find('input.sub-save-line-item-quantity').val());
    var start_date = save.parents('tr').find('input[name="start_date"]').val();
    var discontinue_on = save.parents('tr').find('input[name="discontinue_on"]').val();
    var sfmc_frequency_id;
    var idStr = save.parents('tr').find('select#sfmc_frequency_id').val()
    if (idStr) {
      sfmc_frequency_id = parseInt(idStr)
    } else {
      sfmc_frequency_id = null
    }

    if (quantity <= 0) {
      alert('Quantity should not be blank or 0.');
      return
    }

    toggleLineItemEdit(event.currentTarget);
    updateLineItem(id, {
      quantity: quantity,
      discontinue_on: discontinue_on,
      sfmc_frequency_id: sfmc_frequency_id,
      start_date: start_date
    });
  });
  $('a.delete-sub-save-line-item').click(function(event) {
    if (confirm(Spree.translations.are_you_sure_delete)) {
      var del = $(this);
      var lineItemId = del.data('sub-save-line-item-id');
      toggleLineItemEdit(event.currentTarget);
      deleteLineItem(lineItemId);
    }
  });

  $('[data-hook="admin_sub_saves"] #add_line_item_variant_id').change(function(){
    var variant_id = $(this).val();
    addLineItem(variant_id, 1);
  });

  $('[data-hook=admin_sub_saves_index_search] button').click(function(_) {
    $('#q_email_or_number_or_parent_order_number_or_ship_address_firstname_or_ship_address_lastname_or_ship_address_phone_cont').val($('#quick_search').val());
  })
});

var toggleLineItemEdit = function(currentTarget) {
  var link = $(currentTarget);
  link.parent().find('a.edit-sub-save-line-item').toggle();
  link.parent().find('a.cancel-sub-save-line-item').toggle();
  link.parent().find('a.save-sub-save-line-item').toggle();
  link.parent().find('a.delete-sub-save-line-item').toggle();
  link.parents('tr').find('td.sub-save-line-item-qty-show').toggle();
  link.parents('tr').find('td.sub-save-line-item-qty-edit').toggle();
  link.parents('tr').find('td.sub-save-line-item-start-date-show').toggle();
  link.parents('tr').find('td.sub-save-line-item-start-date-edit').toggle();
  link.parents('tr').find('td.sub-save-line-item-discontinue-on-show').toggle();
  link.parents('tr').find('td.sub-save-line-item-discontinue-on-edit').toggle();
  link.parents('tr').find('td.sub-save-line-item-frequency-show').toggle();
  link.parents('tr').find('td.sub-save-line-item-frequency-edit').toggle();
};

var updateLineItem = function(id, attributes) {
  var membershipId = $('[data-hook="admin_sub_save_edit_form"]').data('sub-save-id');
  var url = Spree.pathFor('api/v1/sub_saves/') + membershipId + '/line_items/' + id;

  $.ajax({
    type: "PUT",
    url: Spree.url(url),
    data: {
      line_item: attributes,
      token: Spree.api_key
    }
  }).done(function(_) {
    reloadWithoutPost();
  }).fail(function(resp) {
    var text = resp.responseJSON.error_messages.join(', ')
    alert(text)
  });
};

var addLineItem = function(variantId, quantity) {
  var id = $('[data-hook="admin_sub_save_edit_form"]').data('sub-save-id');
  var url = Spree.pathFor('api/v1/sub_saves/') + id + '/line_items';

  $.ajax({
    type: "POST",
    url: Spree.url(url),
    data: {
      line_item: {
        variant_id: variantId,
        quantity: quantity
      },
      token: Spree.api_key
    }
  }).done(function(_) {
    reloadWithoutPost();
  }).fail(function(resp) {
    var text = resp.responseJSON.error_messages.join(', ')
    alert(text)
  });
};

var deleteLineItem = function(lineItemId) {
  var id = $('[data-hook="admin_sub_save_edit_form"]').data('sub-save-id');
  var url = Spree.pathFor('api/v1/sub_saves/') + id + '/line_items/' + lineItemId;

  $.ajax({
    type: "DELETE",
    url: Spree.url(url),
    data: {
      token: Spree.api_key
    }
  }).done(function(_) {
    reloadWithoutPost();
  }).fail(function(resp) {
    var text = resp.responseJSON.error_messages.join(', ')
    alert(text)
  });
};

function reloadWithoutPost() {
  window.location = window.location.href.split("#")[0]
}
