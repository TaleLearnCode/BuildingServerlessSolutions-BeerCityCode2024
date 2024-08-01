# #############################################################################
# Terraform Configuration
# #############################################################################

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.53"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
  backend "azurerm" {    
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

provider "azuread" {
}

provider "github" {
  token = var.github_token
}

# #############################################################################
# Variables
# #############################################################################

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

variable "github_token" {
  type        = string
  description = "The GitHub token to authenticate with the GitHub provider."
}

variable "github_repository_full_name" {
  type        = string
  description = "The full name of the GitHub repository."
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
# Referenced Resources
# #############################################################################

data "azurerm_subscription" "current" {}
data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "terraform" {
  name = "${module.resource_group.name.abbreviation}-CoolReviveTerraform-${var.azure_environment}-${module.azure_regions.region.region_short}"
}

data "azurerm_storage_account" "terraform" {
  name                = lower("${module.storage_account.name.abbreviation}Terraform${var.resource_name_suffix}${var.azure_environment}${module.azure_regions.region.region_short}")
  resource_group_name = data.azurerm_resource_group.terraform.name
}

data "github_repository" "cool_revive" {
  full_name = var.github_repository_full_name
}

# #############################################################################
# Custom Role Definitions
# #############################################################################

resource "azurerm_role_definition" "role_assignments" {
  name        = "Terraform Manage Role Assignments"
  scope       = data.azurerm_subscription.current.id
  description = "Provides Terraform service principals the ability to manage role assignments."

  permissions {
    actions     = [
      "Microsoft.Authorization/roleAssignments/Read",
      "Microsoft.Authorization/roleAssignments/Write",
      "Microsoft.Authorization/roleAssignments/Delete",
      "Microsoft.Storage/storageAccounts/listKeys/action"
    ]
    not_actions = []
  }

  assignable_scopes = [
    data.azurerm_subscription.current.id,
  ]
}

# #############################################################################
# Service Principal
# #############################################################################

resource "azuread_application" "terraform_service_principal" {
  display_name = "Terraform Service Principal"
}

resource "azuread_service_principal" "terraform" {
  client_id = azuread_application.terraform_service_principal.client_id
  owners = [data.azurerm_client_config.current.object_id]
}

resource "azuread_service_principal_password" "terraform" {
  service_principal_id = azuread_service_principal.terraform.object_id
}

resource "azurerm_role_assignment" "terraform" {
  scope                = data.azurerm_storage_account.terraform.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.terraform.object_id
}

# #############################################################################
# GitHub Action Secrets
# #############################################################################

locals {
  azure_credentials = jsonencode({
    clientSecret     = azuread_service_principal_password.terraform.value
    subscriptionId   = data.azurerm_client_config.current.subscription_id
    tenantId         = data.azurerm_client_config.current.tenant_id
    clientId         = azuread_service_principal.terraform.client_id
  })
}

resource "github_actions_secret" "azure_credentials" {
  repository       = data.github_repository.cool_revive.name
  secret_name      = "AZURE_CREDENTIALS"
  plaintext_value = local.azure_credentials
}

resource "github_actions_secret" "azure_ad_client_id" {
  repository      = data.github_repository.cool_revive.name
  secret_name     = "AZURE_AD_CLIENT_ID"
  plaintext_value = azuread_service_principal.terraform.client_id
}

resource "github_actions_secret" "azure_ad_client_secret" {
  repository      = data.github_repository.cool_revive.name
  secret_name     = "AZURE_AD_CLIENT_SECRET"
  plaintext_value = azuread_service_principal_password.terraform.value
}

resource "github_actions_secret" "azure_subscription_id" {
  repository      = data.github_repository.cool_revive.name
  secret_name     = "AZURE_SUBSCRIPTION_ID"
  plaintext_value = data.azurerm_client_config.current.subscription_id
}

resource "github_actions_secret" "azure_ad_tenant_id" {
  repository      = data.github_repository.cool_revive.name
  secret_name     = "AZURE_AD_TENANT_ID"
  plaintext_value = data.azurerm_client_config.current.tenant_id
}

resource "github_actions_secret" "terraform_storage_account_name" {
  repository       = data.github_repository.cool_revive.name
  secret_name      = "TERRAFORM_STORAGE_ACCOUNT_NAME"
  plaintext_value = data.azurerm_storage_account.terraform.name
}

resource "github_actions_secret" "terraform_resource_group" {
  repository       = data.github_repository.cool_revive.name
  secret_name      = "TERRAFORM_RESOURCE_GROUP"
  plaintext_value = data.azurerm_resource_group.terraform.name
}