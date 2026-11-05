include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "service" {
  path = find_in_parent_folders("service.hcl")
}

inputs = {
  capacity              = 1
  ssl_cert_kv_secret_id = "https://kv-opr-shd-uat-uks.vault.azure.net/secrets/wildcard-sharedo-co-uk"
}
