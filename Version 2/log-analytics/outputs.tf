# Read by pipelines and operators. Other services do NOT read these - they look the
# resources up by name with data sources, so keep resource names stable.

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.hub.id
}
