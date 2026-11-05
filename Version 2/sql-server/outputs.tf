# Read by pipelines and operators. Other services do NOT read these - they look the
# resources up by name with data sources, so keep resource names stable.

output "sql" {
  value = {
    server_id         = azurerm_mssql_server.shared.id
    server_name       = azurerm_mssql_server.shared.name
    server_fqdn       = azurerm_mssql_server.shared.fully_qualified_domain_name
    elastic_pool_id   = azurerm_mssql_elasticpool.shared.id
    elastic_pool_name = azurerm_mssql_elasticpool.shared.name
  }
}
