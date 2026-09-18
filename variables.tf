variable "subscription_id" {
  description = "Azure subscription in which the new project will be deployed."
  type        = string
}

variable "name_prefix" {
  description = "Lowercase workload name used in resource names."
  type        = string
  default     = "demo-functions"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.name_prefix))
    error_message = "name_prefix must be 3-21 lowercase alphanumeric or hyphen characters and start with a letter."
  }
}

variable "unique_suffix" {
  description = "Lowercase alphanumeric suffix used for globally unique names."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{4,8}$", var.unique_suffix))
    error_message = "unique_suffix must contain 4-8 lowercase alphanumeric characters."
  }
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "francecentral"
}

variable "environment" {
  description = "Environment tag value."
  type        = string
  default     = "dev"
}

variable "storage_account_replication_type" {
  description = "Storage SKU name accepted by the Storage ARM API."
  type        = string
  default     = "Standard_LRS"
}

variable "data_container_name" {
  description = "Blob container read by the sample Function configuration."
  type        = string
  default     = "data"
}

variable "default_blob_name" {
  description = "Default blob name exposed to the Function through app settings."
  type        = string
  default     = "hello.txt"
}

variable "powershell_runtime_version" {
  description = "PowerShell runtime version for Azure Functions."
  type        = string
  default     = "7.4"
}

variable "maximum_instance_count" {
  description = "Maximum number of Flex Consumption instances."
  type        = number
  default     = 100
}

variable "instance_memory_mb" {
  description = "Memory allocated to each Flex Consumption instance."
  type        = number
  default     = 2048
}

variable "function_public_network_access_enabled" {
  description = "Whether the Function endpoint is publicly reachable."
  type        = bool
  default     = true
}

variable "cors_allowed_origins" {
  description = "Origins allowed by the Function App CORS policy."
  type        = list(string)
  default     = ["https://portal.azure.com"]
}

variable "log_retention_days" {
  description = "Log Analytics retention period."
  type        = number
  default     = 30
}

variable "enable_defender_data_scanner_access" {
  description = "Allow the current subscription's Defender for Storage data scanner through the storage firewall."
  type        = bool
  default     = false
}

variable "event_grid_webhook_url" {
  description = "Optional webhook URL for storage BlobCreated events. Leave null to omit Event Grid resources."
  type        = string
  default     = null
  nullable    = true
}

variable "tags" {
  description = "Additional tags to apply to resources."
  type        = map(string)
  default     = {}
}
