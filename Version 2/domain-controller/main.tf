# From operate-iac: hub/compute_domain_controller.tf
# Real contents: Windows VM (var.vm_size), UAMI, set-admin-password Run Command, AD DS
# promotion (scripts/configure-ad.ps1), DNS forwarders (scripts/configure-dns-forwarders.ps1).

locals {
  g      = merge(var.global, var.environments[var.environment])
  naming = "operate-hub-ad"
  tags   = merge(local.g.base_tags, local.g.tags, { service = "Identity" })
}

# Upstream (by name): network hub app subnet.
data "azurerm_subnet" "hub_app" {
  name                 = "snet-operate-hub-app-${local.g.suffix}"
  virtual_network_name = "vnet-operate-hub-${local.g.suffix}"
  resource_group_name  = "rg-operate-hub-networking-${local.g.suffix}"
}

resource "azurerm_resource_group" "ad" {
  name     = "rg-${local.naming}-${local.g.suffix}"
  location = local.g.location
  tags     = local.tags
}

resource "azurerm_network_interface" "ad" {
  name                = "nic-${local.naming}-${local.g.suffix}"
  location            = azurerm_resource_group.ad.location
  resource_group_name = azurerm_resource_group.ad.name
  tags                = local.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.hub_app.id
    private_ip_address_allocation = "Static"
    # Owned by global.tfvars (environments[*].ad_private_ip): every VNet uses it as DNS.
    private_ip_address = local.g.ad_private_ip
  }

  lifecycle {
    precondition {
      condition     = cidrhost(data.azurerm_subnet.hub_app.address_prefixes[0], 68) == local.g.ad_private_ip
      error_message = "environments[\"${var.environment}\"].ad_private_ip must be .68 in the hub app subnet (${data.azurerm_subnet.hub_app.address_prefixes[0]})."
    }
  }
}
