resource "google_storage_bucket" "k8s_manifests" {
  name          = "${local.prfx}k8s-manifests"
  location      = local.gcp_region
  force_destroy = true

  public_access_prevention = "enforced"

  versioning {
    enabled = true
  }
}

resource "google_storage_bucket_object" "k8s_example" {
  name   = "example.yaml"
  content = templatefile("${path.module}/files/k8s/example.yaml.tftpl", {
    ingress_external_ip_name = google_compute_global_address.ingress_external_alb_ip.name
  })
  bucket = google_storage_bucket.k8s_manifests.name
}

resource "google_storage_bucket_object" "k8s_debug_sdk" {
  name   = "debug-sdk.yaml"
  content = templatefile("${path.module}/files/k8s/debug-sdk.yaml.tftpl", {
    gcp_service_account = google_service_account.gke_pod_identity.email
  })
  bucket = google_storage_bucket.k8s_manifests.name
}
