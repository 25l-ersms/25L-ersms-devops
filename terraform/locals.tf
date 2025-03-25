locals {
  gcp_project_id = data.google_client_config.this.project
  gcp_region = data.google_client_config.this.region
  prfx = "${var.resource_prefix}-"

  caller_ip = data.http.caller_ip_response.response_body

  vpc_public_cird = "10.0.0.0/24"
  vpc_private_cird = "10.0.40.0/24"

  iam_account_domain = "${local.gcp_project_id}.iam.gserviceaccount.com"
}
