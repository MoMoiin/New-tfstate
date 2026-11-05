# Read by pipelines and operators. Other services do NOT read these - they look the
# resources up by name with data sources, so keep resource names stable.

output "private_ip" {
  value = azurerm_network_interface.seq.private_ip_address
}

output "public_host" {
  value = "seq-${local.g.env}-${local.g.location_shorthand}.${local.g.public_dns_zone}"
}

output "seq_url" {
  value = "http://${azurerm_network_interface.seq.private_ip_address}:5341"
}
