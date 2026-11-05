# Read by pipelines and operators. customer-app and customer-data look these resources up by
# name with data sources, so keep resource names stable.

output "resource_group_name" {
  value = azurerm_resource_group.networking.name
}

output "vnet_id" {
  value = azurerm_virtual_network.client.id
}

output "subnets" {
  value = {
    app = {
      id             = azurerm_subnet.app.id
      address_prefix = azurerm_subnet.app.address_prefixes[0]
    }
  }
}
