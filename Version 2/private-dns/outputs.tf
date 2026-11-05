# Read by pipelines and operators. Other services do NOT read these - they look the
# resources up by name with data sources, so keep resource names stable.

output "resource_group_name" {
  value = azurerm_resource_group.dns.name
}

output "private_dns_zones" {
  value = {
    for k, z in azurerm_private_dns_zone.this : k => { id = z.id, name = z.name } if k != "operate"
  }
}

output "operate_dns_zone" {
  value = {
    id   = azurerm_private_dns_zone.this["operate"].id
    name = azurerm_private_dns_zone.this["operate"].name
  }
}
