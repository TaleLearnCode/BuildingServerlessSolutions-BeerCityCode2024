# #############################################################################
# Modules
# #############################################################################

module "azure_regions" {
  source       = "git::https://github.com/TaleLearnCode/terraform-azure-regions.git"
  azure_region = var.azure_region
}

module "resource_group" {
  source        = "git::https://github.com/TaleLearnCode/azure-resource-types.git"
  resource_type = "resource-group"
}

module "key_vault" {
  source        = "git::https://github.com/TaleLearnCode/azure-resource-types.git"
  resource_type = "key-vault"
}

module "app_config" {
  source        = "git::https://github.com/TaleLearnCode/azure-resource-types.git"
  resource_type = "app-configuration-store"
}

module "log_analytics_workspace" {
  source        = "git::https://github.com/TaleLearnCode/azure-resource-types.git"
  resource_type = "log-analytics-workspace"
}

module "application_insights" {
  source        = "git::https://github.com/TaleLearnCode/azure-resource-types.git"
  resource_type = "application-insights"
}

module "service_bus_namespace" {
  source        = "git::https://github.com/TaleLearnCode/azure-resource-types.git"
  resource_type = "service-bus-namespace"
}

module "service_bus_topic" {
  source        = "git::https://github.com/TaleLearnCode/azure-resource-types.git"
  resource_type = "service-bus-topic"
}

module "service_bus_topic_subscription" {
  source        = "git::https://github.com/TaleLearnCode/azure-resource-types.git"
  resource_type = "service-bus-topic-subscription"
}

module "storage_account" {
  source        = "git::https://github.com/TaleLearnCode/azure-resource-types.git"
  resource_type = "storage-account"
}

module "app_service_plan" {
  source        = "git::https://github.com/TaleLearnCode/azure-resource-types.git"
  resource_type = "app-service-plan"
}

module "function_app" {
  source        = "git::https://github.com/TaleLearnCode/azure-resource-types.git"
  resource_type = "function-app"
}

module "api_management" {
  source        = "git::https://github.com/TaleLearnCode/azure-resource-types.git"
  resource_type = "api-management-service-instance"
}

module "cosmos_account" {
  source        = "git::https://github.com/TaleLearnCode/azure-resource-types.git"
  resource_type = "azure-cosmos-db-for-nosql-account"
}