# Read by pipelines and operators. Other services do NOT read these - they look the
# resources up by name with data sources, so keep resource names stable.

output "key_vault_id" {
  value = azurerm_key_vault.hub.id
}

output "key_vault_uri" {
  value = azurerm_key_vault.hub.vault_uri
}
