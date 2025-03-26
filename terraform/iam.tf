resource "google_service_account" "bastion_service_account" {
  account_id   = "${local.prfx}bastion"
  display_name = "Bastion"
}

resource "google_project_iam_binding" "bastion_service_account_iam_binding" {
  for_each = toset([
    "roles/cloudsql.client",
    "roles/storage.objectViewer"
  ])
  project = local.gcp_project_id
  role    = each.value

  members = [
    google_service_account.bastion_service_account.member,
  ]
}
