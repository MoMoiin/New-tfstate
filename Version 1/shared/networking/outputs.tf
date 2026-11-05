# Read by pipelines and operators. Other services do NOT read these - they look the
# resources up by name with data sources, so keep resource names stable.

output "resource_group_name" {
  value = azurerm_resource_group.networking.name
}

output "vnet" {
  value = {
    id   = azurerm_virtual_network.shared.id
    name = azurerm_virtual_network.shared.name
  }
}

output "subnets" {
  value = {
    for k, s in azurerm_subnet.this : k => {
      id             = s.id
      address_prefix = s.address_prefixes[0]
    }
  }
}
