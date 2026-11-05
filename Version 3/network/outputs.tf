# Read by pipelines and operators. Other services do NOT read these - they look the
# resources up by name with data sources, so keep resource names stable.

output "hub" {
  value = {
    resource_group_name = azurerm_resource_group.hub.name
    vnet = {
      id            = azurerm_virtual_network.hub.id
      name          = azurerm_virtual_network.hub.name
      address_space = azurerm_virtual_network.hub.address_space
    }
    subnets = {
      for k, s in azurerm_subnet.hub : k => {
        id             = s.id
        address_prefix = s.address_prefixes[0]
      }
    }
  }
}

output "shared" {
  value = {
    resource_group_name = azurerm_resource_group.shared.name
    vnet = {
      id            = azurerm_virtual_network.shared.id
      name          = azurerm_virtual_network.shared.name
      address_space = azurerm_virtual_network.shared.address_space
    }
    subnets = {
      for k, s in azurerm_subnet.shared : k => {
        id             = s.id
        address_prefix = s.address_prefixes[0]
      }
    }
  }
}
