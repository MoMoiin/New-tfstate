# From operate-iac: shared/compute_prizm.tf, security_key_vault_prizm.tf, scripts/prizm/
# Real contents: Windows VM (var.vm_size) + data disk, its Key Vault, CSE bootstrap
# (scripts/vm/windows/initialize-disks.ps1, join-domain.ps1), Datadog agent.

locals {
  g      = merge(var.global, var.environments[var.environment])
  naming = "operate-shared-prizm"
  tags   = merge(local.g.base_tags, local.g.tags, { service = "Prizm" })
}

# Upstream (by name): network shared vm subnet.
data "azurerm_subnet" "vm" {
  name                 = "snet-operate-shared-vm-${local.g.suffix}"
  virtual_network_name = "vnet-operate-shared-${local.g.suffix}"
  resource_group_name  = "rg-operate-shared-networking-${local.g.suffix}"
}

resource "azurerm_resource_group" "prizm" {
  name     = "rg-${local.naming}-${local.g.suffix}"
  location = local.g.location
  tags     = local.tags
}

resource "azurerm_network_interface" "prizm" {
  name                = "nic-${local.naming}-${local.g.suffix}"
  location            = azurerm_resource_group.prizm.location
  resource_group_name = azurerm_resource_group.prizm.name
  tags                = local.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.vm.id
    private_ip_address_allocation = "Dynamic"
  }
}

# prizm.operate.internal - the workload owns its own record in the hub zone (private-dns).
resource "azurerm_private_dns_a_record" "prizm" {
  name                = "prizm"
  zone_name           = local.g.operate_dns_zone
  resource_group_name = "rg-operate-hub-dns-${local.g.suffix}"
  ttl                 = 300
  records             = [azurerm_network_interface.prizm.private_ip_address]
  tags                = local.tags
}
