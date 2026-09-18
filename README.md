# Greenfield Azure Functions Terraform project

This project creates a new Azure Functions environment from scratch. It does
not import, query, or reference infrastructure from another resource group.

## Architecture

- Resource group
- Linux Flex Consumption plan
- PowerShell Function App
- User-assigned managed identity
- StorageV2 account with shared-key authentication disabled
- Blob containers for deployment, Functions runtime data, and application data
- Storage RBAC for the Function identity
- Network Security Perimeter and enforced storage association
- Log Analytics workspace
- Function and Blob service diagnostic settings
- Optional Event Grid system topic and BlobCreated webhook subscription

Application code is deployed separately. Terraform creates the Function App and
its deployment container but does not publish a function package.

## Configure

Edit `main.tfvars.json`:

```json
{
  "subscription_id": "00000000-0000-0000-0000-000000000000",
  "name_prefix": "demo-functions",
  "unique_suffix": "a1b2c3",
  "environment": "dev",
  "location": "francecentral"
}
```

`unique_suffix` must contain 4-8 lowercase letters or digits. It prevents
collisions for globally unique Function App and storage account names.

Set `event_grid_webhook_url` only when a real webhook endpoint is available.
The Event Grid resources are omitted by default.

## Deploy

```bash
az login
az account set --subscription <subscription-id>
terraform init
terraform plan -var-file=main.tfvars.json -out=main.tfplan
terraform apply main.tfplan
```

The initial plan should contain only creates. Review it before applying.

## Security notes

- Storage shared-key and anonymous blob access are disabled.
- Storage uses TLS 1.2 and deny-by-default network rules.
- Storage data-plane containers are provisioned through ARM/AzAPI so deployment
  does not require opening the Network Security Perimeter.
- The Function uses a user-assigned identity and Azure RBAC for storage access.
- The Function remains publicly reachable by default to match an HTTP-triggered
  workload. Set `function_public_network_access_enabled` to `false` only after
  adding private connectivity.
