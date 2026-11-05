# From operate-iac: shared/network_app_gateway.tf
# Real contents: WAF_v2 gateway shell (var.capacity, var.ssl_cert_kv_secret_id) with
# lifecycle.ignore_changes on its sub-resources - per-host pools/listeners/rules are wired
# out-of-band by scripts/lib/AgWiring.ps1.

locals {
  g      = merge(var.global, var.environments[var.environment])
  naming = "operate-shared-appgw"
  tags   = merge(local.g.base_tags, local.g.tags, { service = "Networking" })

}

# Upstream (by name): network shared appgw subnet.
data "azurerm_subnet" "appgw" {
  name                 = "snet-operate-shared-appgw-${local.g.suffix}"
  virtual_network_name = "vnet-operate-shared-${local.g.suffix}"
  resource_group_name  = "rg-operate-shared-networking-${local.g.suffix}"
}

resource "azurerm_resource_group" "appgw" {
  name     = "rg-${local.naming}-${local.g.suffix}"
  location = local.g.location
  tags     = local.tags
}

resource "azurerm_public_ip" "appgw" {
  name                = "pip-${local.naming}-${local.g.suffix}"
  location            = azurerm_resource_group.appgw.location
  resource_group_name = azurerm_resource_group.appgw.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "opr-shd-app-${local.g.env}-${local.g.location_shorthand}"
  tags                = local.tags
}
