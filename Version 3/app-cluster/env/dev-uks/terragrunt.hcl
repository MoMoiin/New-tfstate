include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "service" {
  path = find_in_parent_folders("service.hcl")
}

inputs = {
  vm_count = 1
  vm_size  = "Standard_E2s_v5"
}
