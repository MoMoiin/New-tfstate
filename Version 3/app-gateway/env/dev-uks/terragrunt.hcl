include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "service" {
  path = find_in_parent_folders("service.hcl")
}

inputs = {
  capacity              = 1
  ssl_cert_kv_secret_id = "" # HTTP-only until the wildcard cert is uploaded
}
