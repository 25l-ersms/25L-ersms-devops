locals {
  gcp_project_id = data.google_client_config.this.project
  gcp_region = data.google_client_config.this.region
  prfx = "${var.resource_prefix}-"

  vpc_cird = "10.0.0.0/16"
}
