# Read by pipelines and operators. Other services do NOT read these - they look the
# resources up by name with data sources, so keep resource names stable.

output "hub" {
  value = {
    key_vault_id  = azurerm_key_vault.hub.id
    key_vault_uri = azurerm_key_vault.hub.vault_uri
  }
}

output "shared" {
  value = {
    key_vault_id  = azurerm_key_vault.shared.id
    key_vault_uri = azurerm_key_vault.shared.vault_uri
  }
}
