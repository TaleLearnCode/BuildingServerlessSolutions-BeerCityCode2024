# #############################################################################
#                             Tags
# #############################################################################

variable "tag_cost_center" {
  type        = string
  default     = "Remanufacturing"
  description = "Accounting cost center associated with the resource."
}

variable "tag_system" {
  type        = string
  default     = "Remanufacturing"
  description = "The system or application that the resources are being created for."
}

variable "tag_service" {
  type        = string
  default     = "Order Next Core"
  description = "The product or service that the resources are being created for."
}

variable "tag_criticality" {
  type        = string
  default     = "Medium"
  description = "The business impact of the resource or supported workload. Valid values are Low, Medium, High, Business Unit Critical, Mission Critical."
}

variable "tag_disaster_recovery" {
  type        = string
  default     = "Dev"
  description = "Business criticality of the application, workload, or service. Valid values are Mission Critical, Critical, Essential, Dev."
}

locals {
  tags = {
    CostCenter  = "${var.tag_cost_center}-${var.azure_environment}"
    System      = var.tag_system
    Service     = var.tag_service
    Criticality = var.tag_criticality
    DR          = var.tag_disaster_recovery
    Env         = var.azure_environment
  }
}