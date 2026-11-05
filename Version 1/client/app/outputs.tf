# Read by client/data (KV/SQL grants) and the app-deploy pipeline.

output "identity" {
  value = {
    id           = azurerm_user_assigned_identity.app.id
    client_id    = azurerm_user_assigned_identity.app.client_id
    principal_id = azurerm_user_assigned_identity.app.principal_id
  }
}

output "app_ips" {
  value = [for n in azurerm_network_interface.app : n.private_ip_address]
}
