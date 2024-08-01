# #############################################################################
# Order Next Core resources
# #############################################################################

# -----------------------------------------------------------------------------
# Resource Group
# -----------------------------------------------------------------------------

resource "azurerm_resource_group" "order_next_core" {
  name     = "${module.resource_group.name.abbreviation}-CoolRevive-Remanufacturing-OrderNextCore-${var.azure_environment}-${module.azure_regions.region.region_short}"
  location = module.azure_regions.region.region_cli
  tags     = local.tags
}

# -----------------------------------------------------------------------------
# Order Next Core Function App
# -----------------------------------------------------------------------------

resource "azurerm_storage_account" "order_next_core_function" {
  name                     = lower("${module.storage_account.name.abbreviation}CRONC${var.resource_name_suffix}${var.azure_environment}${module.azure_regions.region.region_short}")
  resource_group_name      = azurerm_resource_group.order_next_core.name
  location                 = azurerm_resource_group.order_next_core.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = local.tags
}

resource "azurerm_service_plan" "order_next_core" {
  name                = "${module.app_service_plan.name.abbreviation}-CoolRevive-OrderNextCore${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}"
  resource_group_name = azurerm_resource_group.order_next_core.name
  location            = azurerm_resource_group.order_next_core.location
  os_type             = "Linux"
  sku_name            = "Y1"
  tags                = local.tags
}

resource "azurerm_linux_function_app" "order_next_core" {
  name                       = "${module.function_app.name.abbreviation}-CoolRevive-OrderNextCore${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}"
  resource_group_name        = azurerm_resource_group.order_next_core.name
  location                   = azurerm_resource_group.order_next_core.location
  storage_account_name       = azurerm_storage_account.order_next_core_function.name
  storage_account_access_key = azurerm_storage_account.order_next_core_function.primary_access_key
  service_plan_id            = azurerm_service_plan.order_next_core.id
  tags                       = local.tags
  

  site_config {
    ftps_state             = "FtpsOnly"
    application_stack {
      dotnet_version              = "8.0"
      use_dotnet_isolated_runtime = true
    }
    application_insights_connection_string = azurerm_application_insights.remanufacturing.connection_string
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    "AzureWebJobsStorage__accountName" = azurerm_storage_account.order_next_core_function.name,
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.remanufacturing.connection_string
}
  lifecycle {
    ignore_changes = [storage_uses_managed_identity]
  }
}

resource "azurerm_role_assignment" "order_next_core_key_vault_secrets_user" {
  scope                = azurerm_key_vault.remanufacturing.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_function_app.order_next_core.identity.0.principal_id
}

resource "azurerm_role_assignment" "order_next_core_app_configuration_data_owner" {
  scope                = azurerm_app_configuration.remanufacturing.id
  role_definition_name = "App Configuration Data Owner"
  principal_id         = azurerm_linux_function_app.order_next_core.identity.0.principal_id
}

# -----------------------------------------------------------------------------
# Service Bus Topic: Get Next Core
# -----------------------------------------------------------------------------

resource "azurerm_servicebus_topic" "get_next_core" {
  name                      = "${module.service_bus_topic.name.abbreviation}-CoolRevive-GetNextCore${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}"
  namespace_id              = azurerm_servicebus_namespace.remanufacturing.id
  support_ordering          = true
}

resource "azurerm_servicebus_subscription" "getnextcore_getnextcore" {
  name                                      = "${module.service_bus_topic_subscription.name.abbreviation}-CoolRevive-GetNextCore${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}"
  topic_id                                  = azurerm_servicebus_topic.get_next_core.id
  dead_lettering_on_filter_evaluation_error = false
  dead_lettering_on_message_expiration      = true
  max_delivery_count                        = 10
  depends_on = [
    azurerm_servicebus_topic.get_next_core,
  ]
}

# -----------------------------------------------------------------------------
# Service Bus Topic: Order Next Core
# -----------------------------------------------------------------------------

resource "azurerm_servicebus_topic" "order_next_core" {
  name                      = "${module.service_bus_topic.name.abbreviation}-CoolRevive-OrderNextCore${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}"
  namespace_id              = azurerm_servicebus_namespace.remanufacturing.id
  support_ordering          = true
}

resource "azurerm_servicebus_subscription" "ordernextcore_ordernextcore" {
  name                                      = "${module.service_bus_topic_subscription.name.abbreviation}-CoolRevive-OrderNextCore${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}"
  topic_id                                  = azurerm_servicebus_topic.order_next_core.id
  dead_lettering_on_filter_evaluation_error = false
  dead_lettering_on_message_expiration      = true
  max_delivery_count                        = 10
  depends_on = [
    azurerm_servicebus_topic.get_next_core,
  ]
}