include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "service" {
  path = find_in_parent_folders("service.hcl")
}

inputs = {
  image_version     = "1.0.0" # operate-client in hub-image-gallery
  vm_app_size       = "Standard_D2s_v5"
  vm_instance_count = 1
}
