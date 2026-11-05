sql_admin_group = {
  login     = "Dev-AzureSQL-Admins"
  object_id = "00000000-0000-0000-0000-0000000000a1"
}

elastic_pool = {
  sku_name     = "GP_Gen5"
  tier         = "GeneralPurpose"
  family       = "Gen5"
  capacity     = 2
  max_size_gb  = 100
  min_capacity = 0
  max_capacity = 2
}