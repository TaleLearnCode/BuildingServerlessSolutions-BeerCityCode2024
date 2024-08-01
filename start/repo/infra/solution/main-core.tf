# #############################################################################
# Core resources
# #############################################################################

# -----------------------------------------------------------------------------
# Resource Group
# -----------------------------------------------------------------------------

resource "azurerm_resource_group" "remanufacturing" {
  name     = "${module.resource_group.name.abbreviation}-CoolRevive-Remanufacturing-${var.azure_environment}-${module.azure_regions.region.region_short}"
  location = module.azure_regions.region.region_cli
  tags     = local.tags
}

# -----------------------------------------------------------------------------
# Key Vault
# -----------------------------------------------------------------------------

resource "azurerm_key_vault" "remanufacturing" {
  name                        = lower("${module.resource_group.name.abbreviation}-CRReman${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}")
  location                    = azurerm_resource_group.remanufacturing.location
  resource_group_name         = azurerm_resource_group.remanufacturing.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = true
  sku_name                    = "standard"
  enable_rbac_authorization  = true
}

resource "azurerm_role_assignment" "key_vault" {
  scope                = azurerm_key_vault.remanufacturing.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# -----------------------------------------------------------------------------
# App Configuration
# -----------------------------------------------------------------------------

resource "azurerm_app_configuration" "remanufacturing" {
  name                       = "${module.app_config.name.abbreviation}-CoolRevive-Remanufacturing${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}"
  resource_group_name        = azurerm_resource_group.remanufacturing.name
  location                   = azurerm_resource_group.remanufacturing.location
  sku                        = "standard"
  local_auth_enabled         = true
  public_network_access      = "Enabled"
  purge_protection_enabled   = false
  soft_delete_retention_days = 1
  tags = local.tags
}

resource "azurerm_role_assignment" "app_configuration" {
  scope                = azurerm_app_configuration.remanufacturing.id
  role_definition_name = "App Configuration Data Owner"
  principal_id         = data.azurerm_client_config.current.object_id
}

# -----------------------------------------------------------------------------
# Log Analytics Workspace
# -----------------------------------------------------------------------------

resource "azurerm_log_analytics_workspace" "remanufacturing" {
  name                = "${module.log_analytics_workspace.name.abbreviation}-CoolRevive-Remanufacturing${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}"
  location            = azurerm_resource_group.remanufacturing.location
  resource_group_name = azurerm_resource_group.remanufacturing.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

# -----------------------------------------------------------------------------
# Application Insights: Catalog (appi-catalog)
# -----------------------------------------------------------------------------

resource "azurerm_application_insights" "remanufacturing" {
  name                = "${module.application_insights.name.abbreviation}-CoolRevive-Remanufacturing${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}"
  location            = azurerm_resource_group.remanufacturing.location
  resource_group_name = azurerm_resource_group.remanufacturing.name
  workspace_id        = azurerm_log_analytics_workspace.remanufacturing.id
  application_type    = "web"
  tags                = local.tags
}

# -----------------------------------------------------------------------------
# Service Bus Namespace
# -----------------------------------------------------------------------------

resource "azurerm_servicebus_namespace" "remanufacturing" {
  name                = "${module.service_bus_namespace.name.abbreviation}-CoolRevive-Remanufacturing${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}"
  location            = azurerm_resource_group.remanufacturing.location
  resource_group_name = azurerm_resource_group.remanufacturing.name
  sku                 = "Standard"

  tags = {
    source = "terraform"
  }
}

resource "azurerm_servicebus_namespace_authorization_rule" "apim-send" {
  name         = "APIMSend"
  namespace_id = azurerm_servicebus_namespace.remanufacturing.id
  listen = false
  send   = true
  manage = false
}