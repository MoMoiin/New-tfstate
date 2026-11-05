# Read by pipelines and operators. Other services take the DC IP from global.tfvars
# (environments[*].ad_private_ip), not from here.

output "ad" {
  value = {
    private_ip  = azurerm_network_interface.ad.private_ip_address
    domain_name = local.g.domain_name
  }
}
