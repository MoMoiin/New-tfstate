include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "service" {
  path = find_in_parent_folders("service.hcl")
}

inputs = {
  allowed_ips                = ["203.0.113.10"]
  database_max_size_gb       = 20
  soft_delete_retention_days = 7
}
