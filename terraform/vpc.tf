module "vpc" {
    source  = "terraform-google-modules/network/google"
    version = "~> 10.0"

    project_id   = local.gcp_project_id
    network_name = "${local.prfx}vpc"
    routing_mode = "REGIONAL"

    subnets = [
        {
            subnet_name               = "${local.prfx}private-subnet"
            subnet_ip                 = local.vpc_private_cird
            subnet_region             = local.gcp_region
            # enable if needed
            # subnet_flow_logs          = "true"
            # subnet_flow_logs_interval = "INTERVAL_10_MIN"
            # subnet_flow_logs_sampling = 0.7
            # subnet_flow_logs_metadata = "INCLUDE_ALL_METADATA"
        },
        {
            subnet_name               = "${local.prfx}public-subnet"
            subnet_ip                 = local.vpc_public_cird
            subnet_region             = local.gcp_region
            # enable if needed
            # subnet_flow_logs          = "true"
            # subnet_flow_logs_interval = "INTERVAL_10_MIN"
            # subnet_flow_logs_sampling = 0.7
            # subnet_flow_logs_metadata = "INCLUDE_ALL_METADATA"
        }
    ]
}

# Router and Cloud NAT are required for installing packages from repos (apache, php etc)
resource "google_compute_router" "group1" {
  name    = "${local.prfx}gw-group1"
  network = module.vpc.network_self_link
  region  = local.gcp_region
}

module "cloud-nat-group1" {
  source     = "terraform-google-modules/cloud-nat/google"
  version    = "~> 5.0"
  router     = google_compute_router.group1.name
  project_id = local.gcp_project_id
  region     = local.gcp_region
  name       = "${local.prfx}cloud-nat-group1"
}

resource "google_compute_firewall" "vpc_private_internal" {
  name    = "${local.prfx}vpc-internal-firewall"
  network = module.vpc.network_self_link

  priority = 65534

  direction = "INGRESS"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  source_ranges = [ local.vpc_private_cird ]
}

resource "google_compute_firewall" "bastion_inbound" {
  name    = "${local.prfx}bastion-inbound-firewall"
  network = module.vpc.network_self_link

  priority = 100

  direction = "INGRESS"
  
  allow {
    protocol = "tcp"
    ports    = ["${var.bastion_ssh_port}"]
  }

  source_ranges = [ "${local.caller_ip}/32" ]
  target_service_accounts = [ google_service_account.bastion_service_account.email ]
}
