resource "random_password" "elasticsearch_root_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "google_secret_manager_secret" "elasticsearch_root_password" {
  secret_id = "${local.prfx}elasticsearch-root-password"

  replication {
    user_managed {
      replicas {
        location = local.gcp_region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "elasticsearch_root_password_initial" {
  secret                = google_secret_manager_secret.elasticsearch_root_password.id
  secret_data           = base64encode(random_password.elasticsearch_root_password.result)
  is_secret_data_base64 = true
}

resource "google_secret_manager_secret_iam_binding" "elasticsearch_root_password_elsasticsearch_secretaccessor_binding" {
  project   = local.gcp_project_id
  secret_id = google_secret_manager_secret.elasticsearch_root_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  members = [
    google_service_account.elasticsearch_service_account.member,
    google_service_account.gke_pod_identity.member
  ]
}

resource "google_secret_manager_secret_iam_binding" "elasticsearch_root_password_elsasticsearch_secretversionadder_binding" {
  project   = local.gcp_project_id
  secret_id = google_secret_manager_secret.elasticsearch_root_password.secret_id
  role      = "roles/secretmanager.secretVersionAdder"
  members = [
    google_service_account.elasticsearch_service_account.member,
  ]
}

resource "google_secret_manager_secret" "elasticsearch_cacert" {
  secret_id = "${local.prfx}elasticsearch-cacert"

  replication {
    user_managed {
      replicas {
        location = local.gcp_region
      }
    }
  }
}

resource "google_secret_manager_secret_iam_binding" "elasticsearch_cacert_elsasticsearch_secretaccessor_binding" {
  project   = local.gcp_project_id
  secret_id = google_secret_manager_secret.elasticsearch_cacert.secret_id
  role      = "roles/secretmanager.secretAccessor"
  members = [
    google_service_account.elasticsearch_service_account.member,
    google_service_account.gke_pod_identity.member
  ]
}

resource "google_secret_manager_secret_iam_binding" "elasticsearch_cacert_elsasticsearch_secretversionadder_binding" {
  project   = local.gcp_project_id
  secret_id = google_secret_manager_secret.elasticsearch_cacert.secret_id
  role      = "roles/secretmanager.secretVersionAdder"
  members = [
    google_service_account.elasticsearch_service_account.member,
  ]
}

resource "random_password" "visit_manager_postgres_generated_password_root" {
  count            = var.visit_manager_postgres_root_password == null ? 1 : 0
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "visit_manager_postgres_generated_password_user" {
  count            = var.visit_manager_postgres_user_password == null ? 1 : 0
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "google_secret_manager_secret" "postgres_root_password" {
  secret_id = "${local.prfx}postgres-root-password"

  replication {
    user_managed {
      replicas {
        location = local.gcp_region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "postgres_root_password_initial" {
  secret                = google_secret_manager_secret.postgres_root_password.id
  secret_data           = base64encode(coalesce(var.visit_manager_postgres_root_password, random_password.visit_manager_postgres_generated_password_root[0].result))
  is_secret_data_base64 = true
}

resource "google_secret_manager_secret_iam_binding" "postgres_root_password_secretaccessor_binding" {
  project   = local.gcp_project_id
  secret_id = google_secret_manager_secret.postgres_root_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  members = [
    google_service_account.elasticsearch_service_account.member,
    google_service_account.gke_pod_identity.member
  ]
}

resource "google_secret_manager_secret" "postgres_user_password" {
  secret_id = "${local.prfx}postgres-user-password"

  replication {
    user_managed {
      replicas {
        location = local.gcp_region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "postgres_user_password_initial" {
  secret                = google_secret_manager_secret.postgres_user_password.id
  secret_data           = base64encode(coalesce(var.visit_manager_postgres_user_password, random_password.visit_manager_postgres_generated_password_user[0].result))
  is_secret_data_base64 = true
}

resource "google_secret_manager_secret_iam_binding" "postgres_user_password_secretaccessor_binding" {
  project   = local.gcp_project_id
  secret_id = google_secret_manager_secret.postgres_user_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  members = [
    google_service_account.elasticsearch_service_account.member,
    google_service_account.gke_pod_identity.member
  ]
}
