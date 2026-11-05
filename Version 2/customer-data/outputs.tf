# Read by the app-deploy pipeline (connection strings, KV URI).

output "database_id" {
  value = azurerm_mssql_database.app.id
}

output "storage_account_id" {
  value = azurerm_storage_account.app.id
}

output "key_vault" {
  value = {
    id  = azurerm_key_vault.app.id
    uri = azurerm_key_vault.app.vault_uri
  }
}
