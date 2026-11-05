# Read by pipelines and operators. Other services do NOT read these - they look the
# resources up by name with data sources, so keep resource names stable.

output "storage_account_id" {
  value = azurerm_storage_account.images.id
}

output "images_container_url" {
  value = "${azurerm_storage_account.images.primary_blob_endpoint}${azurerm_storage_container.images.name}"
}
