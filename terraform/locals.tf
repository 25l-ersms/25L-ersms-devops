locals {
  gcp_project_id     = data.google_client_config.this.project
  gcp_project_number = data.google_project.this.number
  gcp_region         = data.google_client_config.this.region
  prfx               = "${var.resource_prefix}-"

  caller_ip = data.http.caller_ip_response.response_body

  vpc_public_cidr                = "10.0.0.0/16"
  vpc_private_cidr               = "10.80.0.0/16"
  vpc_ip_range_gke_pods          = "vpc-ip-range-gke-pods"
  vpc_ip_range_gke_pods_cidr     = "10.40.0.0/18"
  vpc_ip_range_gke_services      = "vpc-ip-range-gke-services"
  vpc_ip_range_gke_services_cidr = "10.40.64.0/18"

  iam_account_domain = "${local.gcp_project_id}.iam.gserviceaccount.com"

  internal_dns_domain                  = "vpc.internal"
  elasticsearch_internal_dns_subdomain = "elasticsearch"
}
