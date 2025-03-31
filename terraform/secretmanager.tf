resource "random_password" "elasticsearch_root_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "google_secret_manager_secret" "elasticsearch_root_password" {
  secret_id = "elasticsearch-root-password"

  replication {
    user_managed {
        replicas {
            location = local.gcp_region
        }
    }
  }
}

resource "google_secret_manager_secret_version" "elasticsearch_root_password_initial" {
  secret = google_secret_manager_secret.elasticsearch_root_password.id
  secret_data = base64encode(random_password.elasticsearch_root_password.result)
  is_secret_data_base64 = true
}

resource "google_secret_manager_secret_iam_binding" "elasticsearch_root_password_elsasticsearch_binding" {
for_each = toset([
    "roles/secretmanager.secretAccessor",
    "roles/secretmanager.secretVersionAdder"
  ])
  project = local.gcp_project_id
  secret_id = google_secret_manager_secret.elasticsearch_root_password.secret_id
  role = each.value
  members = [
    google_service_account.elasticsearch_service_account.member
  ]
}

resource "google_secret_manager_secret" "elasticsearch_cacert" {
  secret_id = "elasticsearch-cacert"

  replication {
    user_managed {
        replicas {
            location = local.gcp_region
        }
    }
  }
}

resource "google_secret_manager_secret_iam_binding" "elasticsearch_cacert_elsasticsearch_binding" {
  for_each = toset([
    "roles/secretmanager.secretAccessor",
    "roles/secretmanager.secretVersionAdder"
  ])
  project = local.gcp_project_id
  secret_id = google_secret_manager_secret.elasticsearch_cacert.secret_id
  role = each.value
  members = [
    google_service_account.elasticsearch_service_account.member
  ]
}

resource "google_secret_manager_secret_iam_binding" "gke_pod_identity_binding" {
  for_each = toset([
    google_secret_manager_secret.elasticsearch_root_password.secret_id,
    google_secret_manager_secret.elasticsearch_cacert.secret_id
  ])
  project = local.gcp_project_id
  secret_id = each.value
  role = "roles/secretmanager.secretAccessor"
  members = [
    google_service_account.gke_pod_identity.member
  ]
}
