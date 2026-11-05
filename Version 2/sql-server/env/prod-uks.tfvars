sql_admin_group = {
  login     = "Prod-AzureSQL-Admins"
  object_id = "00000000-0000-0000-0000-0000000000a3"
}

elastic_pool = {
  sku_name     = "GP_Gen5"
  tier         = "GeneralPurpose"
  family       = "Gen5"
  capacity     = 8
  max_size_gb  = 500
  min_capacity = 0
  max_capacity = 8
}