resource "google_compute_address" "bastion_ip" {
  name = "${local.prfx}bastion-external-ipv4"
}

resource "google_compute_instance" "bastion" {
  name         = "${local.prfx}bastion"
  machine_type = var.bastion_instance_size
  zone         = "${local.gcp_region}-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-2404-noble-amd64-v20250313"
    }
  }

  network_interface {
    network    = module.vpc.network_self_link
    subnetwork = module.vpc.subnets["${local.gcp_region}/${var.resource_prefix}-public-subnet"].self_link
    access_config {
      nat_ip = google_compute_address.bastion_ip.address
    }
  }

  service_account {
    email = google_service_account.bastion_service_account.email
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  allow_stopping_for_update = true

  metadata = {
    "startup-script" : resource.terraform_data.bastion_startup_script.output
  }
}

# GCP does not provide ElasticSearch as a managed service, we'll have to deploy it ourselves
# TODO mount EBS volume or whatever it's called
resource "google_compute_instance" "elasticsearch" {
  name         = "${local.prfx}elasticsearch"
  machine_type = var.elasticsearch_instance_size
  zone         = "${local.gcp_region}-a"

  hostname = "${local.elasticsearch_internal_dns_subdomain}.${local.internal_dns_domain}"

  boot_disk {
    initialize_params {
      image = "ubuntu-2404-noble-amd64-v20250313"
    }
  }

  network_interface {
    network    = module.vpc.network_self_link
    subnetwork = module.vpc.subnets["${local.gcp_region}/${var.resource_prefix}-private-subnet"].self_link
  }

  service_account {
    email = google_service_account.elasticsearch_service_account.email
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  allow_stopping_for_update = true

  metadata = {
    "startup-script" : resource.terraform_data.elasticsearch_startup_script.output
  }
}
