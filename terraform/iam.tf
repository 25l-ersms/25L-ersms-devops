resource "google_service_account" "bastion_service_account" {
  account_id   = "${local.prfx}bastion"
  display_name = "Bastion"
}

resource "google_project_iam_binding" "bastion_service_account_iam_binding" {
  for_each = toset([
    "roles/cloudsql.client",
    "roles/storage.objectViewer",
    "roles/iam.serviceAccountUser",
    "roles/container.developer",
    "roles/container.viewer"
  ])
  project = local.gcp_project_id
  role    = each.value

  members = [
    google_service_account.bastion_service_account.member,
  ]
}

resource "google_project_iam_binding" "kafka_service_account_iam_binding" {
  for_each = toset([
    "roles/managedkafka.client",
    "roles/managedkafka.viewer"
  ])
  project = local.gcp_project_id
  role    = each.value

  members = [
    google_service_account.bastion_service_account.member,
    google_service_account.gke_pod_identity.member,
    google_service_account.gke_pod_identity_visit_sched.member,
    google_service_account.gke_pod_identity_visit_man.member,
    google_service_account.gke_pod_identity_user_chat.member,
  ]
}

resource "google_project_iam_binding" "firestore_service_account_iam_binding_gke" {
  for_each = toset([
    "roles/datastore.user"
  ])
  project = local.gcp_project_id
  role    = each.value

  members = [
    google_service_account.gke_pod_identity.member,
    google_service_account.gke_pod_identity_user_chat.member,
  ]
}

resource "google_project_iam_binding" "firestore_service_account_iam_binding_bastion" {
  for_each = toset([
    "roles/datastore.owner"
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

# allow GKE to manage firewall rules
# https://cloud.google.com/kubernetes-engine/docs/concepts/ingress#providing_the_ingress_controller_permission_to_manage_host_project_firewall_rules
resource "google_project_iam_binding" "gke_ingress_controller_iam_binding" {
  project = local.gcp_project_id
  role    = "roles/compute.securityAdmin"

  members = [
    "serviceAccount:service-${local.gcp_project_number}@container-engine-robot.iam.gserviceaccount.com"
  ]
}

# Managed Kafka will not work with workload identity federation for GKE:
# https://cloud.google.com/iam/docs/federated-identity-supported-services#google-cloud-managed-service-for-apache-kafka
# As an alternative, we can create an IAM service account with required permissions and allow k8s service account to impersonate it:
# https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity#kubernetes-sa-to-iam
resource "google_service_account" "gke_pod_identity" {
  account_id   = "${local.prfx}gke-pod"
  display_name = "GKE pod (example)"
}

# resource "google_project_iam_binding" "gke_iam_workflow_identity_iam_binding" {
#   for_each = toset([
#     "roles/iam.workloadIdentityUser"
#   ])
#   project = local.gcp_project_id
#   role    = each.value

#   members = [
#     "serviceAccount:${local.gcp_project_id}.svc.id.goog[default/debug-sdk-sa]"
#   ]
# }

resource "google_service_account" "gke_pod_identity_external_secrets" {
  account_id   = "${local.prfx}eso"
  display_name = "Service Account for External Secrets Operator on GKE"
}

resource "google_project_iam_binding" "gke_pod_identity_external_secrets_iam_binding1" {
  for_each = toset([
    "roles/secretmanager.secretAccessor",
    "roles/iam.serviceAccountTokenCreator"
  ])
  project = local.gcp_project_id
  role    = each.value

  members = [
    google_service_account.gke_pod_identity_external_secrets.member
  ]
}

resource "google_service_account" "gke_pod_identity_visit_sched" {
  account_id   = "${local.prfx}visit-sched"
  display_name = "Service Account for Visit Scheduler on GKE"
}

resource "google_service_account" "gke_pod_identity_visit_man" {
  account_id   = "${local.prfx}visit-man"
  display_name = "Service Account for Visit Manager on GKE"
}

resource "google_service_account" "gke_pod_identity_user_chat" {
  account_id   = "${local.prfx}user-chat"
  display_name = "Service Account for User Chat on GKE"
}

resource "google_project_iam_binding" "gke_pod_identity_user_chat_iam_binding" {
  project = local.gcp_project_id
  role    = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${local.gcp_project_id}.svc.id.goog[visit-sched-ns/visit-sched]",
    "serviceAccount:${local.gcp_project_id}.svc.id.goog[visit-man-ns/visit-man]",
    "serviceAccount:${local.gcp_project_id}.svc.id.goog[user-chat-ns/user-chat]",
    "serviceAccount:${local.gcp_project_id}.svc.id.goog[visit-sched-ns/external-secrets]",
    "serviceAccount:${local.gcp_project_id}.svc.id.goog[visit-man-ns/external-secrets]",
    "serviceAccount:${local.gcp_project_id}.svc.id.goog[user-chat-ns/external-secrets]",
  ]
}
