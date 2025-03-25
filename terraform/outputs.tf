output "region" {
  value = local.gcp_region
}

output "project" {
  value = local.gcp_project_id
}

output "bastion_ip" {
  value = google_compute_address.bastion_ip.address
}

# output "lb_ip" {
#   value = module.gce-lb-http.external_ip
# }
