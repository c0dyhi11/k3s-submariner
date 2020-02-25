provider "packet" {
    auth_token = var.auth_token
}

resource "random_string" "bgp_password" {
  length = 18
  min_lower = 6
  min_upper = 6
  min_numeric = 6
}

resource "packet_project" "new_project" {
    name = var.project_name
    organization_id = var.organization_id
    bgp_config {
        deployment_type = "local"
        asn = var.bgp_asn
        md5 = random_string.bgp_password.result
   }
}
