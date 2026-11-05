# Read by pipelines and operators. Other services do NOT read these - they look the
# resources up by name with data sources, so keep resource names stable.

output "datadog_identity" {
  value = {
    id           = azurerm_user_assigned_identity.datadog.id
    client_id    = azurerm_user_assigned_identity.datadog.client_id
    principal_id = azurerm_user_assigned_identity.datadog.principal_id
  }
}
