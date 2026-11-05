# Read by pipelines and operators. Other services do NOT read these - they look the
# resources up by name with data sources, so keep resource names stable.

output "identity" {
  value = {
    id           = azurerm_user_assigned_identity.ci_runner.id
    client_id    = azurerm_user_assigned_identity.ci_runner.client_id
    principal_id = azurerm_user_assigned_identity.ci_runner.principal_id
  }
}
