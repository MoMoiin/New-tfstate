# From operate-iac: shared/compute_seq.tf, security_key_vault_seq.tf, scripts/seq/
# Real contents: Windows VM (var.vm_size) + data disk, its Key Vault, CSE bootstrap. The
# App Gateway host and public CNAME are wired by the pipeline (AgWiring.ps1, PublicDns.ps1).

locals {
  g      = merge(var.global, var.environments[var.environment])
  naming = "operate-shared-seq"
  tags   = merge(local.g.base_tags, local.g.tags, { service = "Seq" })
}

# Upstream (by name): shared/networking vm subnet.
data "azurerm_subnet" "vm" {
  name                 = "snet-operate-shared-vm-${local.g.suffix}"
  virtual_network_name = "vnet-operate-shared-${local.g.suffix}"
  resource_group_name  = "rg-operate-shared-networking-${local.g.suffix}"
}

resource "azurerm_resource_group" "seq" {
  name     = "rg-${local.naming}-${local.g.suffix}"
  location = local.g.location
  tags     = local.tags
}

resource "azurerm_network_interface" "seq" {
  name                = "nic-${local.naming}-${local.g.suffix}"
  location            = azurerm_resource_group.seq.location
  resource_group_name = azurerm_resource_group.seq.name
  tags                = local.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.vm.id
    private_ip_address_allocation = "Dynamic"
  }
}

# seq.operate.internal - the workload owns its own record in the hub zone (hub/dns).
resource "azurerm_private_dns_a_record" "seq" {
  name                = "seq"
  zone_name           = local.g.operate_dns_zone
  resource_group_name = "rg-operate-hub-dns-${local.g.suffix}"
  ttl                 = 300
  records             = [azurerm_network_interface.seq.private_ip_address]
  tags                = local.tags
}
