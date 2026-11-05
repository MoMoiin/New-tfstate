# Read by pipelines and operators. Other services do NOT read these - they look the
# resources up by name with data sources, so keep resource names stable.

output "private_ip" {
  value = azurerm_network_interface.prizm.private_ip_address
}
