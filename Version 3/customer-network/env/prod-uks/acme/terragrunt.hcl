include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "service" {
  path = find_in_parent_folders("service.hcl")
}

inputs = {
  # prod customer IPAM: 10.144.0.0/12 -> per-customer /22. Allocated: 10.144.0.0/22
  address_space = "10.144.0.0/22"
}
