# #############################################################################
# Notification Manager resources
# #############################################################################

# -----------------------------------------------------------------------------
# Service Bus Topic: Next Core in Transit
# -----------------------------------------------------------------------------

resource "azurerm_servicebus_subscription" "nextcoreintransit_notificationmanager" {
  name                                      = "${module.service_bus_topic_subscription.name.abbreviation}-CoolRevive-NCIT-NotifyMgr${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}"
  topic_id                                  = azurerm_servicebus_topic.order_next_core.id
  dead_lettering_on_filter_evaluation_error = false
  dead_lettering_on_message_expiration      = true
  max_delivery_count                        = 10
}