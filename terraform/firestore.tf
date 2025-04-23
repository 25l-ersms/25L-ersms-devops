resource "google_firestore_database" "database" {
  project     = local.gcp_project_id
  name        = "ersms"
  location_id = local.gcp_region
  type        = "FIRESTORE_NATIVE"
}
