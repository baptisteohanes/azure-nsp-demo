data "azurerm_client_config" "current" {}

locals {
  compact_prefix       = replace(var.name_prefix, "-", "")
  resource_group_name  = "rg-${var.name_prefix}"
  storage_account_name = substr("st${local.compact_prefix}${var.unique_suffix}", 0, 24)
  service_plan_name    = "asp-${var.name_prefix}"
  function_app_name    = "func-${var.name_prefix}-${var.unique_suffix}"
  log_analytics_name   = "log-${var.name_prefix}"
  perimeter_name       = "nsp-${var.name_prefix}"
  system_topic_name    = "evgt-${var.name_prefix}-${var.unique_suffix}"
  deployment_container = "app-package-${local.function_app_name}"

  tags = merge(var.tags, {
    environment = var.environment
    workload    = var.name_prefix
    managed-by  = "terraform"
  })
}

resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.tags
}

resource "azurerm_user_assigned_identity" "function" {
  name                = "id-${var.name_prefix}-function"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = local.log_analytics_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  retention_in_days   = var.log_retention_days
  sku                 = "PerGB2018"
  tags                = local.tags
}

resource "azurerm_network_security_perimeter" "main" {
  name                = local.perimeter_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

resource "azurerm_network_security_perimeter_profile" "storage" {
  name                          = "storage"
  network_security_perimeter_id = azurerm_network_security_perimeter.main.id
}

resource "azurerm_network_security_perimeter_access_rule" "subscription" {
  name                                  = "allow-subscription-resources"
  direction                             = "Inbound"
  network_security_perimeter_profile_id = azurerm_network_security_perimeter_profile.storage.id
  subscription_ids                      = ["/subscriptions/${var.subscription_id}"]
}

resource "azapi_resource" "storage" {
  type      = "Microsoft.Storage/storageAccounts@2025-01-01"
  name      = local.storage_account_name
  parent_id = azurerm_resource_group.main.id
  location  = azurerm_resource_group.main.location

  body = {
    kind = "StorageV2"
    properties = {
      accessTier                   = "Hot"
      allowBlobPublicAccess        = false
      allowCrossTenantReplication  = false
      allowSharedKeyAccess         = false
      defaultToOAuthAuthentication = true
      minimumTlsVersion            = "TLS1_2"
      publicNetworkAccess          = "SecuredByPerimeter"
      supportsHttpsTrafficOnly     = true
      networkAcls = {
        bypass              = "None"
        defaultAction       = "Deny"
        ipRules             = []
        virtualNetworkRules = []
        resourceAccessRules = var.enable_defender_data_scanner_access ? [{
          resourceId = "/subscriptions/${var.subscription_id}/providers/Microsoft.Security/datascanners/StorageDataScanner"
          tenantId   = data.azurerm_client_config.current.tenant_id
        }] : []
      }
    }
    sku = {
      name = var.storage_account_replication_type
    }
  }

  tags = local.tags
}

resource "azurerm_network_security_perimeter_association" "storage" {
  name                                  = "storage-account"
  access_mode                           = "Enforced"
  network_security_perimeter_profile_id = azurerm_network_security_perimeter_profile.storage.id
  resource_id                           = azapi_resource.storage.id
}

resource "azapi_resource" "blob_service" {
  type      = "Microsoft.Storage/storageAccounts/blobServices@2025-01-01"
  name      = "default"
  parent_id = azapi_resource.storage.id
  body = {
    properties = {}
  }
}

resource "azapi_resource" "blob_container" {
  for_each = toset([
    local.deployment_container,
    "azure-webjobs-hosts",
    "azure-webjobs-secrets",
    var.data_container_name,
  ])

  type      = "Microsoft.Storage/storageAccounts/blobServices/containers@2025-01-01"
  name      = each.value
  parent_id = azapi_resource.blob_service.id
  body = {
    properties = {
      publicAccess = "None"
    }
  }
}

resource "azurerm_role_assignment" "function_storage_blob_owner" {
  scope                = azapi_resource.storage.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_user_assigned_identity.function.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "function_storage_blob_contributor" {
  scope                = azapi_resource.storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.function.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "function_storage_queue_contributor" {
  scope                = azapi_resource.storage.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_user_assigned_identity.function.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "function_storage_table_contributor" {
  scope                = azapi_resource.storage.id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = azurerm_user_assigned_identity.function.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "function_monitoring_metrics_publisher" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_user_assigned_identity.function.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_service_plan" "function" {
  #checkov:skip=CKV_AZURE_212:Flex Consumption automatically scales and has no fixed failover instance count.
  #checkov:skip=CKV_AZURE_225:FC1 does not expose zone-balancing settings.
  name                = local.service_plan_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = "FC1"
  tags                = local.tags
}

resource "azurerm_function_app_flex_consumption" "main" {
  name                = local.function_app_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.function.id

  runtime_name    = "powershell"
  runtime_version = var.powershell_runtime_version

  storage_container_type                         = "blobContainer"
  storage_container_endpoint                     = "https://${local.storage_account_name}.blob.core.windows.net/${local.deployment_container}"
  storage_authentication_type                    = "UserAssignedIdentity"
  storage_user_assigned_identity_id              = azurerm_user_assigned_identity.function.id
  maximum_instance_count                         = var.maximum_instance_count
  instance_memory_in_mb                          = var.instance_memory_mb
  public_network_access_enabled                  = var.function_public_network_access_enabled
  https_only                                     = true
  client_certificate_mode                        = "Required"
  webdeploy_publish_basic_authentication_enabled = false

  app_settings = {
    AzureWebJobsStorage__blobServiceUri  = "https://${local.storage_account_name}.blob.core.windows.net"
    AzureWebJobsStorage__queueServiceUri = "https://${local.storage_account_name}.queue.core.windows.net"
    AzureWebJobsStorage__tableServiceUri = "https://${local.storage_account_name}.table.core.windows.net"
    AzureWebJobsStorage__credential      = "managedidentity"
    AzureWebJobsStorage__clientId        = azurerm_user_assigned_identity.function.client_id
    BlobStorage__blobServiceUri          = "https://${local.storage_account_name}.blob.core.windows.net"
    BlobStorage__credential              = "managedidentity"
    BlobStorage__clientId                = azurerm_user_assigned_identity.function.client_id
    BLOB_CONTAINER                       = var.data_container_name
    BLOB_NAME                            = var.default_blob_name
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.function.id]
  }

  site_config {
    minimum_tls_version     = "1.2"
    scm_minimum_tls_version = "1.2"

    cors {
      allowed_origins = var.cors_allowed_origins
    }
  }

  tags = local.tags

  depends_on = [
    azapi_resource.blob_container,
    azurerm_role_assignment.function_monitoring_metrics_publisher,
    azurerm_role_assignment.function_storage_blob_contributor,
    azurerm_role_assignment.function_storage_blob_owner,
    azurerm_role_assignment.function_storage_queue_contributor,
    azurerm_role_assignment.function_storage_table_contributor,
  ]
}

resource "azurerm_monitor_diagnostic_setting" "function" {
  name                       = "send-to-log-analytics"
  target_resource_id         = azurerm_function_app_flex_consumption.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "blob_service" {
  name                       = "send-to-log-analytics"
  target_resource_id         = azapi_resource.blob_service.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  enabled_metric {
    category = "Transaction"
  }
}

resource "azurerm_eventgrid_system_topic" "storage" {
  count = var.event_grid_webhook_url == null ? 0 : 1

  name                   = local.system_topic_name
  location               = azurerm_resource_group.main.location
  resource_group_name    = azurerm_resource_group.main.name
  source_arm_resource_id = azapi_resource.storage.id
  topic_type             = "Microsoft.Storage.StorageAccounts"
  tags                   = local.tags
}

resource "azurerm_eventgrid_system_topic_event_subscription" "storage_blob_created" {
  count = var.event_grid_webhook_url == null ? 0 : 1

  name                = "blob-created-webhook"
  resource_group_name = azurerm_resource_group.main.name
  system_topic        = azurerm_eventgrid_system_topic.storage[0].name
  included_event_types = [
    "Microsoft.Storage.BlobCreated",
  ]

  advanced_filter {
    string_contains {
      key    = "data.blobType"
      values = ["BlockBlob"]
    }
  }

  webhook_endpoint {
    url                               = var.event_grid_webhook_url
    max_events_per_batch              = 1
    preferred_batch_size_in_kilobytes = 64
  }
}
