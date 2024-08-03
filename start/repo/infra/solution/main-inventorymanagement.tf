# #############################################################################
# Inventory Management resources
# #############################################################################

# -----------------------------------------------------------------------------
# Resource Group
# -----------------------------------------------------------------------------

resource "azurerm_resource_group" "inventory_manager" {
  name     = "${module.resource_group.name.abbreviation}-CoolRevive-Remanufacturing-InventoryManager-${var.azure_environment}-${module.azure_regions.region.region_short}"
  location = module.azure_regions.region.region_cli
  tags     = local.tags
}

# -----------------------------------------------------------------------------
# Cosmos DB
# -----------------------------------------------------------------------------

resource "azurerm_cosmosdb_account" "inventory_manager" {
  name                = lower("${module.cosmos_account.name.abbreviation}-CoolRevive-InventoryMgr${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}")
  location            = azurerm_resource_group.inventory_manager.location
  resource_group_name = azurerm_resource_group.inventory_manager.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  capabilities {
    name = "EnableServerless"
  }
  consistency_policy {
    consistency_level       = "Session"
    max_interval_in_seconds = 5
    max_staleness_prefix    = 100
  }
  geo_location {
    location          = azurerm_resource_group.inventory_manager.location
    failover_priority = 0
  }
  tags = local.tags
}

resource "azurerm_role_definition" "cosmos_read_write" {
  name        = "Cosmos DB Account Read/Write"
  scope       = data.azurerm_subscription.current.id
  description = "Provides Terraform service principals the ability to manage role assignments."

  permissions {
    actions     = [
      "Microsoft.DocumentDB/databaseAccounts/services/read",
      "Microsoft.DocumentDB/databaseAccounts/services/write",
      "Microsoft.DocumentDB/databaseAccounts/services/delete"
    ]
    not_actions = []
  }

  assignable_scopes = [
    data.azurerm_subscription.current.id,
  ]
}

resource "azurerm_role_assignment" "search_cosmos" {
  scope                = azurerm_cosmosdb_account.inventory_manager.id
  role_definition_name = "Cosmos DB Account Read/Write"
  principal_id         = azurerm_linux_function_app.inventory_manager.identity[0].principal_id
}

resource "azurerm_cosmosdb_sql_database" "inventory_manager" {
  name                = "inventory-manager"
  resource_group_name = azurerm_cosmosdb_account.inventory_manager.resource_group_name
  account_name        = azurerm_cosmosdb_account.inventory_manager.name
}

resource "azurerm_cosmosdb_sql_container" "inventory_manager" {
  name                  = "inventory-manager-events"
  resource_group_name   = azurerm_cosmosdb_account.inventory_manager.resource_group_name
  account_name          = azurerm_cosmosdb_account.inventory_manager.name
  database_name         = azurerm_cosmosdb_sql_database.inventory_manager.name
  partition_key_paths   = ["/finishedProductId"]
}

# -----------------------------------------------------------------------------
# Inventory Manager Function App
# -----------------------------------------------------------------------------

resource "azurerm_storage_account" "inventory_manager_function" {
  name                     = lower("${module.storage_account.name.abbreviation}CRINV${var.resource_name_suffix}${var.azure_environment}${module.azure_regions.region.region_short}")
  resource_group_name      = azurerm_resource_group.inventory_manager.name
  location                 = azurerm_resource_group.inventory_manager.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = local.tags
}

resource "azurerm_service_plan" "inventory_manager" {
  name                = "${module.app_service_plan.name.abbreviation}-CoolRevive-InventoryManager${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}"
  resource_group_name = azurerm_resource_group.inventory_manager.name
  location            = azurerm_resource_group.inventory_manager.location
  os_type             = "Linux"
  sku_name            = "Y1"
  tags                = local.tags
}

resource "azurerm_linux_function_app" "inventory_manager" {
  name                       = "${module.function_app.name.abbreviation}-CoolRevive-InventoryManager${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}"
  resource_group_name        = azurerm_resource_group.inventory_manager.name
  location                   = azurerm_resource_group.inventory_manager.location
  storage_account_name       = azurerm_storage_account.inventory_manager_function.name
  storage_account_access_key = azurerm_storage_account.inventory_manager_function.primary_access_key
  service_plan_id            = azurerm_service_plan.inventory_manager.id
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
    "AzureWebJobsStorage__accountName" = azurerm_storage_account.inventory_manager_function.name,
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.remanufacturing.connection_string
}
  lifecycle {
    ignore_changes = [storage_uses_managed_identity]
  }
}

resource "azurerm_role_assignment" "key_vault_secrets_user" {
  scope                = azurerm_key_vault.remanufacturing.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_function_app.inventory_manager.identity.0.principal_id
}

resource "azurerm_role_assignment" "app_configuration_data_owner" {
  scope                = azurerm_app_configuration.remanufacturing.id
  role_definition_name = "App Configuration Data Owner"
  principal_id         = azurerm_linux_function_app.inventory_manager.identity.0.principal_id
}

# -----------------------------------------------------------------------------
# Service Bus Topic: Order Next Core
# -----------------------------------------------------------------------------

resource "azurerm_servicebus_subscription" "ordernextcore_inventorymanager" {
  name                                      = "${module.service_bus_topic_subscription.name.abbreviation}-CoolRevive-ONC-InventoryManager${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}"
  topic_id                                  = azurerm_servicebus_topic.order_next_core.id
  dead_lettering_on_filter_evaluation_error = false
  dead_lettering_on_message_expiration      = true
  max_delivery_count                        = 10
}