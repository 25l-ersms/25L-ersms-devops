output "region" {
  value = local.gcp_region
}

output "project" {
  value = local.gcp_project_id
}

output "bastion_ip" {
  value = google_compute_address.bastion_ip.address
}

# Enterprise plus is required... seriously, Google?
# https://cloud.google.com/sql/docs/mysql/instance-info#view-write-endpoint
output "postgres_dns_name" {
  value = module.pg.dns_name
}
output "postgres_ip" {
  value = module.pg.private_ip_address
}

output "postgres_root_username" {
  value = var.visit_manager_postgres_root_user
}

output "postgres_root_password" {
  value = coalesce(var.visit_manager_postgres_root_password, random_password.visit_manager_postgres_generated_password_root[0].result)
  sensitive = true
}

output "postgres_user_username" {
  value = module.pg.additional_users[0].name
}

output "postgres_user_password" {
  value = module.pg.additional_users[0].password
  sensitive = true
}

output "elasticsearch_ip" {
  value = google_compute_instance.elasticsearch.network_interface[0].network_ip 
}
