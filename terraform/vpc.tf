module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 10.0"

  project_id   = local.gcp_project_id
  network_name = "${local.prfx}vpc"
  routing_mode = "REGIONAL"

  subnets = [
    {
      subnet_name           = "${local.prfx}private-subnet"
      subnet_ip             = local.vpc_private_cidr
      subnet_region         = local.gcp_region
      subnet_private_access = true
    },
    {
      subnet_name           = "${local.prfx}public-subnet"
      subnet_ip             = local.vpc_public_cidr
      subnet_region         = local.gcp_region
      subnet_private_access = true
    }
  ]

  secondary_ranges = {
    ("${local.prfx}private-subnet") = [
      {
        range_name    = local.vpc_ip_range_gke_pods
        ip_cidr_range = local.vpc_ip_range_gke_pods_cidr
      },
      {
        range_name    = local.vpc_ip_range_gke_services
        ip_cidr_range = local.vpc_ip_range_gke_services_cidr
      },
    ]
  }
}

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

  source_ranges = [local.vpc_private_cidr]
}

resource "google_compute_firewall" "gke_to_es_outbound" {
  name    = "${local.prfx}gke-to-es-outbound-firewall"
  network = module.vpc.network_self_link

  priority = 200

  direction = "EGRESS"

  allow {
    protocol = "tcp"
    ports    = [9200, 9300]
  }

  target_service_accounts = [module.gke.service_account]
}

resource "google_compute_firewall" "bastion_inbound" {
  name    = "${local.prfx}bastion-inbound-firewall"
  network = module.vpc.network_self_link

  priority = 100

  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = [var.bastion_ssh_port]
  }

  source_ranges           = ["${local.caller_ip}/32"]
  target_service_accounts = [google_service_account.bastion_service_account.email]
}

resource "google_compute_firewall" "bastion_outbound_postgres" {
  name    = "${local.prfx}bastion-outbound-postgres-firewall"
  network = module.vpc.network_self_link

  priority = 100

  direction = "EGRESS"

  allow {
    protocol = "tcp"
    ports    = [var.visit_manager_postgres_port]

  }

  target_service_accounts = [module.pg.instance_service_account_email_address]
}

resource "google_compute_firewall" "bastion_outbound_elasticsearch" {
  name    = "${local.prfx}bastion-outbound-elasticsearch-firewall"
  network = module.vpc.network_self_link

  priority = 100

  direction = "EGRESS"

  allow {
    protocol = "tcp"
    ports    = [9200]

  }

  target_service_accounts = [google_service_account.elasticsearch_service_account.email]
}

resource "google_compute_firewall" "elasticsearch_inbound_ssh" {
  name    = "${local.prfx}elasticsearch-ssh-inbound-firewall"
  network = module.vpc.network_self_link

  priority = 123

  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = [22]

  }

  source_service_accounts = [
    google_service_account.bastion_service_account.email
  ]
  target_service_accounts = [google_service_account.elasticsearch_service_account.email]
}

resource "google_compute_firewall" "elasticsearch_inbound_https_bastion" {
  name    = "${local.prfx}elasticsearch-https-inbound-bastion-firewall"
  network = module.vpc.network_self_link

  priority = 123

  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = [9200, 9300]
  }

  source_service_accounts = [
    google_service_account.bastion_service_account.email,
  ]
  target_service_accounts = [google_service_account.elasticsearch_service_account.email]
}

# GKE does not work with service accounts... for some reason
resource "google_compute_firewall" "elasticsearch_inbound_https_gke" {
  name    = "${local.prfx}elasticsearch-https-inbound-gke-firewall"
  network = module.vpc.network_self_link

  priority = 123

  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = [9200, 9300]
  }

  source_ranges = [
    local.vpc_ip_range_gke_pods_cidr,
    local.vpc_ip_range_gke_services_cidr
  ]
  target_service_accounts = [google_service_account.elasticsearch_service_account.email]
}
