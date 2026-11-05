include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "service" {
  path = find_in_parent_folders("service.hcl")
}

inputs = {
  sql_admin_group = {
    login     = "Uat-AzureSQL-Admins"
    object_id = "00000000-0000-0000-0000-0000000000a2"
  }
  elastic_pool = {
    sku_name     = "GP_Gen5"
    tier         = "GeneralPurpose"
    family       = "Gen5"
    capacity     = 4
    max_size_gb  = 250
    min_capacity = 0
    max_capacity = 4
  }
}
