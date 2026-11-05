# From operate-iac: shared/compute_app_cluster.tf, compute_app_cluster_lb.tf,
# storage_app_cluster.tf, security_key_vault_app.tf, scripts/app_cluster/
# Real contents: var.vm_count Windows VMs (var.vm_size) running Elasticsearch + EventStore,
# internal LB, bootstrap storage, the app Key Vault.

locals {
  g      = var.context
  naming = "operate-shared-ac"
  tags   = merge(local.g.tags, { service = "AppCluster" })

  nodes = { for i in range(var.vm_count) : format("%02d", i + 1) => i }
}

# Upstream (by name): network shared app_cluster subnet.
data "azurerm_subnet" "app_cluster" {
  name                 = "snet-operate-shared-app-cluster-${local.g.suffix}"
  virtual_network_name = "vnet-operate-shared-${local.g.suffix}"
  resource_group_name  = "rg-operate-shared-networking-${local.g.suffix}"
}

resource "azurerm_resource_group" "app_cluster" {
  name     = "rg-${local.naming}-${local.g.suffix}"
  location = local.g.location
  tags     = local.tags
}

resource "azurerm_network_interface" "node" {
  for_each = local.nodes

  name                = "nic-${local.naming}-${local.g.env}-${local.g.location_shorthand}-${each.key}"
  location            = azurerm_resource_group.app_cluster.location
  resource_group_name = azurerm_resource_group.app_cluster.name
  tags                = local.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.app_cluster.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(data.azurerm_subnet.app_cluster.address_prefixes[0], 10 + each.value)
  }
}

# es-01.operate.internal, ... - the workload owns its own records in the hub zone (private-dns).
resource "azurerm_private_dns_a_record" "node" {
  for_each = azurerm_network_interface.node

  name                = "es-${each.key}"
  zone_name           = local.g.operate_dns_zone
  resource_group_name = "rg-operate-hub-dns-${local.g.suffix}"
  ttl                 = 300
  records             = [each.value.private_ip_address]
  tags                = local.tags
}
