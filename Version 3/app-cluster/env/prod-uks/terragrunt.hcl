include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "service" {
  path = find_in_parent_folders("service.hcl")
}

inputs = {
  vm_count = 3
  vm_size  = "Standard_E8s_v5"
}
