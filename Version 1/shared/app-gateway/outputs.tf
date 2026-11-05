# Read by pipelines and operators. Other services do NOT read these - they look the
# resources up by name with data sources, so keep resource names stable.

output "app_gateway" {
  value = {
    name                            = "agw-${local.naming}-${local.g.suffix}"
    resource_group_name             = azurerm_resource_group.appgw.name
    public_ip                       = azurerm_public_ip.appgw.ip_address
    public_ip_fqdn                  = azurerm_public_ip.appgw.fqdn
    private_ip                      = cidrhost(data.azurerm_subnet.appgw.address_prefixes[0], 10)
    frontend_ip_config_public_name  = "appGwPublicFrontendIpIPv4"
    frontend_ip_config_private_name = "appGwPrivateFrontendIpIPv4"
    frontend_port_http_name         = "port-80"
    frontend_port_https_name        = "port-443"
    ssl_cert_kv_secret_id           = var.ssl_cert_kv_secret_id
  }
}
