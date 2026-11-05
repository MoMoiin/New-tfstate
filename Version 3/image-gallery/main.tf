# From operate-iac: hub/image_gallery.tf. Image versions are published by packer/, not here.

locals {
  g      = var.context
  naming = "operate-hub-images"
  tags   = merge(local.g.tags, { service = "Compute" })
}

resource "azurerm_resource_group" "images" {
  name     = "rg-${local.naming}-${local.g.suffix}"
  location = local.g.location
  tags     = local.tags
}

resource "azurerm_shared_image_gallery" "images" {
  name                = "gal_${replace(local.naming, "-", "_")}_${replace(local.g.suffix, "-", "_")}"
  location            = azurerm_resource_group.images.location
  resource_group_name = azurerm_resource_group.images.name
  tags                = local.tags
}

resource "azurerm_shared_image" "this" {
  for_each = var.image_definitions

  name                = each.key
  gallery_name        = azurerm_shared_image_gallery.images.name
  resource_group_name = azurerm_resource_group.images.name
  location            = azurerm_resource_group.images.location
  os_type             = each.value
  hyper_v_generation  = "V2"
  tags                = local.tags

  identifier {
    publisher = "clio-operate"
    offer     = each.key
    sku       = "default"
  }
}
