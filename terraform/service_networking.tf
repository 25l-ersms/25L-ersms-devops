resource "google_compute_global_address" "private_ip_alloc" {
  name          = "${local.prfx}-private-ip-alloc"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = module.vpc.network_id
}

resource "google_service_networking_connection" "default" {
  network                 = module.vpc.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]

  # will not de-provision correctly
  # https://github.com/hashicorp/terraform-provider-google/issues/16275
  deletion_policy = "ABANDON"
}
