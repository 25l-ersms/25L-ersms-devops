output "region" {
  value = local.gcp_region
}

output "project" {
  value = local.gcp_project_id
}

output "bastion_ip" {
  value = google_compute_address.bastion_ip.address
}

#####################
# VISIT MANAGER SQL #
#####################

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

#################################
# VISIT SCHEDULER ELASTICSEARCH #
#################################

output "elasticsearch_ip" {
  value = google_compute_instance.elasticsearch.network_interface[0].network_ip 
}

#########
# KAFKA #
#########

# according to https://cloud.google.com/managed-service-for-apache-kafka/docs/quickstart#use_the_kafka_command_line_tools
output "kafka_bootstrap_url" {
  value = "bootstrap.${google_managed_kafka_cluster.kafka.cluster_id}.${google_managed_kafka_cluster.kafka.location}.managedkafka.${local.gcp_project_id}.cloud.goog:9092"
}

#######
# GKE #
#######

output "gke_cluster_name" {
  value = module.gke.name
}
output "gke_cluster_endpoint" {
  value = module.gke.endpoint
}
output "gke_cluster_dns_endpoint" {
  value = module.gke.endpoint_dns
}

output "ingress_global_ip_name" {
  value = google_compute_global_address.ingress_external_alb_ip.name
}

output "ingress_global_ip_address" {
  value = google_compute_global_address.ingress_external_alb_ip.address
}

#################
# ElasticSearch #
#################

output "elasticsearch_dns_name" {
  value = trimsuffix(google_dns_record_set.elsasticsearch.name, ".")
}

output "elasticsearch_private_ip" {
  value = google_compute_instance.elasticsearch.network_interface[0].network_ip
}

###########
# Storage #
###########

output "k8s_manifests_bucket_url" {
  value = google_storage_bucket.k8s_manifests.url
}
