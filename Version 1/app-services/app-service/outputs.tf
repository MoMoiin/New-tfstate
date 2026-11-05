# Read by the app-deploy pipeline.

output "web_app" {
  value = {
    id               = azurerm_windows_web_app.app.id
    name             = azurerm_windows_web_app.app.name
    default_hostname = azurerm_windows_web_app.app.default_hostname
  }
}
