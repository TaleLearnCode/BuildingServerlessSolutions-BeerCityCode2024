# #############################################################################
# Next Core in Transit resources
# #############################################################################

# -----------------------------------------------------------------------------
# Service Bus Topic: Next Core in Transit
# -----------------------------------------------------------------------------

resource "azurerm_servicebus_topic" "next_core_in_transit" {
  name                      = "${module.service_bus_topic.name.abbreviation}-CoolRevive-NextCoreInTransit${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}"
  namespace_id              = azurerm_servicebus_namespace.remanufacturing.id
  support_ordering          = true
}