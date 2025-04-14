resource "google_dns_managed_zone" "internal-zone" {
  name        = "internal-zone"
  dns_name    = "${local.internal_dns_domain}."
  description = "Private DNS zone for VPC-internal services"

  visibility = "private"

  private_visibility_config {
    gke_clusters {
      gke_cluster_name = module.gke.cluster_id
    }

    networks {
      network_url = module.vpc.network_id
    }
  }
}

resource "google_dns_record_set" "elsasticsearch" {
  name = "${local.elasticsearch_internal_dns_subdomain}.${local.internal_dns_domain}."
  type = "A"
  ttl  = 300

  managed_zone = google_dns_managed_zone.internal-zone.name

  rrdatas = [google_compute_instance.elasticsearch.network_interface[0].network_ip]
}
