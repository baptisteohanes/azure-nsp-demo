output "resource_group_id" {
  description = "ID of the new resource group."
  value       = azurerm_resource_group.main.id
}

output "function_app_id" {
  description = "ID of the new Flex Consumption Function App."
  value       = azurerm_function_app_flex_consumption.main.id
}

output "function_app_name" {
  description = "Name of the new Function App."
  value       = azurerm_function_app_flex_consumption.main.name
}

output "function_app_default_hostname" {
  description = "Azure-provided hostname for the new Function App."
  value       = azurerm_function_app_flex_consumption.main.default_hostname
}

output "storage_account_id" {
  description = "ID of the new storage account."
  value       = azapi_resource.storage.id
}

output "network_security_perimeter_id" {
  description = "ID of the new Network Security Perimeter."
  value       = azurerm_network_security_perimeter.main.id
}

output "function_identity_principal_id" {
  description = "Principal ID of the Function App user-assigned identity."
  value       = azurerm_user_assigned_identity.function.principal_id
}
