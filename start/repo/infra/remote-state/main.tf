# #############################################################################
#                          Terraform Configuration
# #############################################################################

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

provider "azurerm" {
  skip_provider_registration = true
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

provider "local" {

}

# #############################################################################
#                          Modules
# #############################################################################

module "azure_regions" {
  source       = "git::https://github.com/TaleLearnCode/terraform-azure-regions.git"
  azure_region = var.azure_region
}

module "resource_group" {
  source        = "git::https://github.com/TaleLearnCode/azure-resource-types.git"
  resource_type = "resource-group"
}

module "storage_account" {
  source        = "git::https://github.com/TaleLearnCode/azure-resource-types.git"
  resource_type = "storage-account"
}

# #############################################################################
#                          Variables
# ############################################################################

variable "azure_region" {
	type        = string
	description = "Location of the resource group."
}

variable "azure_environment" {
	type        = string
	description = "The environment component of an Azure resource name."
}

variable "resource_name_suffix" {
  type        = string
  description = "The suffix to append to the resource names."
}

# #############################################################################
#                          Define the Tags
# #############################################################################

locals {
  criticality = var.azure_environment == "dev" ? "Medium" : var.azure_environment == "qa" ? "High" : var.azure_environment == "e2e" ? "High" : var.azure_environment == "prod" ? "Mission Critical" : "Medium"
  disaster_recovery = var.azure_environment == "dev" ? "Dev" : var.azure_environment == "qa" ? "Dev" : var.azure_environment == "e2e" ? "Dev" : var.azure_environment == "prod" ? "Mission Critical" : "Dev"
  tags = {
    Product      = "InfrastructureAsCode"
    Criticiality = local.criticality
    CostCenter   = "InfrastructureAsCode-${var.azure_environment}"
    DR           = local.disaster_recovery
    Env          = var.azure_environment
  }
}

# #############################################################################
#                       AzureRM Provider Configuration
# #############################################################################

data "azurerm_client_config" "current" {}

# #############################################################################
#                           Resource Group
# #############################################################################

resource "azurerm_resource_group" "rg" {
  name     = "${module.resource_group.name.abbreviation}-CoolReviveTerraform-${var.azure_environment}-${module.azure_regions.region.region_short}"
  location = module.azure_regions.region.region_cli
  tags     = local.tags
}

# #############################################################################
#                           Storage Account
# #############################################################################

resource "azurerm_storage_account" "st" {
  name                            = lower("${module.storage_account.name.abbreviation}Terraform${var.resource_name_suffix}${var.azure_environment}${module.azure_regions.region.region_short}")
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  allow_nested_items_to_be_public = false

  tags = local.tags
}

resource "azurerm_storage_container" "remote_state" {
  name                 = "terraform-state"
  storage_account_name = azurerm_storage_account.st.name
}

data "azurerm_storage_account_sas" "state" {
  connection_string = azurerm_storage_account.st.primary_connection_string
  https_only        = true

  resource_types {
    service   = true
    container = true
    object    = true
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  start  = timestamp()
  expiry = timeadd(timestamp(), "17520h")

  permissions {
    read    = true
    write   = true
    delete  = true
    list    = true
    add     = true
    create  = true
    update  = false
    process = false
    tag     = false
    filter  = false
  }
}

# #############################################################################
#                        Generate the TFConfig File
# #############################################################################

resource "local_file" "post-config" {
  depends_on = [azurerm_storage_container.remote_state]

  filename = "${var.azure_environment}.tfconfig"
  content  = <<EOF
storage_account_name = "${azurerm_storage_account.st.name}"
container_name = "terraform-state"
key = "iac.tfstate"
sas_token = "${data.azurerm_storage_account_sas.state.sas}"

  EOF
}