# #############################################################################
# Common Variables
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