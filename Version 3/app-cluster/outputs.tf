# Read by pipelines and operators. Other services do NOT read these - they look the
# resources up by name with data sources, so keep resource names stable.

output "node_ips" {
  value = { for k, n in azurerm_network_interface.node : k => n.private_ip_address }
}

output "app_cluster" {
  value = {
    elasticsearch_hosts = join(",", [for n in azurerm_network_interface.node : "http://${n.private_ip_address}:9200"])
    eventstore_hosts    = join(",", [for n in azurerm_network_interface.node : n.private_ip_address])
  }
}
