module "mig1_template" {
  source     = "terraform-google-modules/vm/google//modules/instance_template"
  version    = "~> 12.0"
  project_id = local.gcp_project_id
  network    = module.vpc.network_self_link
  subnetwork = module.vpc.subnets["europe-west2/ersms-test-private-subnet"].self_link
  service_account = {
    email  = ""
    scopes = ["cloud-platform"]
  }
  name_prefix          = "${local.prfx}group1"
  startup_script       = <<EOT
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y nginx
service nginx start
EOT
  source_image_family  = "ubuntu-2004-lts"
  source_image_project = "ubuntu-os-cloud"
  machine_type = "e2-small"
  tags = [
    # "${var.network_prefix}-group1",
    module.cloud-nat-group1.router_name
  ]
}

module "mig1" {
  source            = "terraform-google-modules/vm/google//modules/mig"
  version           = "~> 12.0"
  project_id = local.gcp_project_id
  instance_template = module.mig1_template.self_link
  region            = local.gcp_region
  hostname          = "${local.prfx}group1"
  target_size       = 2
  named_ports = [{
    name = "http",
    port = 80
  }]
}
