# Read by pipelines and operators. Other services do NOT read these - they look the
# resources up by name with data sources, so keep resource names stable.

output "gallery_id" {
  value = azurerm_shared_image_gallery.images.id
}

output "image_ids" {
  value = { for k, i in azurerm_shared_image.this : k => i.id }
}
