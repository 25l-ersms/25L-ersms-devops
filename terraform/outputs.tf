output "region" {
  value = local.gcp_region
}

output "project" {
  value = local.gcp_project_id
}

output "lb_ip" {
  value = module.gce-lb-http.external_ip
}
