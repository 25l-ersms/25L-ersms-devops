resource "google_compute_address" "bastion_ip" {
  name = "ipv4-address"
}

resource "google_compute_instance" "bastion" {
  name         = "${local.prfx}-bastion"
  machine_type = "e2-micro"
  zone         = "${local.gcp_region}-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-2404-noble-amd64-v20250313"
    }
  }

  network_interface {
    network = module.vpc.network_self_link
    subnetwork = module.vpc.subnets["${local.gcp_region}/${var.resource_prefix}-public-subnet"].self_link
    access_config {
      nat_ip = google_compute_address.bastion_ip.address
    }
  }

  service_account {
    email  = google_service_account.bastion_service_account.email
    scopes = []
  }

  allow_stopping_for_update = true

  metadata = {
    "startup-script": resource.terraform_data.bastion_startup_script.output
  }
}
