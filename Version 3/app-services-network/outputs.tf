# Read by pipelines and operators. app-services-web-app looks the subnet up by name.

output "vnet_id" {
  value = azurerm_virtual_network.appsvc.id
}

output "integration_subnet_id" {
  value = azurerm_subnet.integration.id
}
