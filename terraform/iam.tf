resource "google_service_account" "bastion_service_account" {
  account_id   = "${local.prfx}bastion"
  display_name = "Bastion"
}

resource "google_project_iam_binding" "bastion_service_account_iam_binding" {
  for_each = toset([
    "roles/cloudsql.client",
    "roles/storage.objectViewer",
    "roles/managedkafka.client",
    "roles/managedkafka.viewer",
    "roles/iam.serviceAccountUser"
  ])
  project = local.gcp_project_id
  role    = each.value

  members = [
    google_service_account.bastion_service_account.member,
  ]
}

resource "google_service_account" "elasticsearch_service_account" {
  account_id   = "${local.prfx}elasticsearch"
  display_name = "ElasticSearch"
}

resource "google_service_account" "gke_service_account" {
  account_id   = "${local.prfx}gke"
  display_name = "GKE"
}
