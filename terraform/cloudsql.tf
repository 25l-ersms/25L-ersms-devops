module "pg" {
  source  = "terraform-google-modules/sql-db/google//modules/postgresql"
  version = "~> 25.2"

  name                 = "${local.prfx}visit-manager-postgres"
  random_instance_name = true
  project_id           = local.gcp_project_id
  database_version     = var.visit_manager_postgres_version
  region               = local.gcp_region
  edition = "ENTERPRISE"

  // Master configurations
  tier                            = "db-custom-1-3840"
  zone                            = "${local.gcp_region}-a"
  availability_type               = "ZONAL"
  maintenance_window_day          = 7
  maintenance_window_hour         = 12
  maintenance_window_update_track = "stable"

  deletion_protection = false

#   database_flags = [{ name = "autovacuum", value = "off" }]


  ip_configuration = {
    ipv4_enabled       = false
    ssl_mode           = "ALLOW_UNENCRYPTED_AND_ENCRYPTED" // can also be ENCRYPTED_ONLY
    private_network    = module.vpc.network_self_link
    allocated_ip_range = google_compute_global_address.private_ip_alloc.name
    authorized_networks = []
  }

  backup_configuration = {
    enabled                        = true
    start_time                     = "20:55"
    location                       = null
    point_in_time_recovery_enabled = false
    transaction_log_retention_days = null
    retained_backups               = 365
    retention_unit                 = "COUNT"
  }

  // Read replica configurations
#   read_replica_name_suffix = "-test-ha"
#   read_replicas = [
#     {
#       name                  = "0"
#       zone                  = "us-central1-a"
#       availability_type     = "REGIONAL"
#       tier                  = "db-custom-1-3840"
#       ip_configuration      = local.read_replica_ip_configuration
#       database_flags        = [{ name = "autovacuum", value = "off" }]
#       disk_autoresize       = null
#       disk_autoresize_limit = null
#       disk_size             = null
#       disk_type             = "PD_HDD"
#       user_labels           = { bar = "baz" }
#       encryption_key_name   = null
#     },
#   ]

  db_name      = var.visit_manager_postgres_db_name
  db_charset   = "UTF8"
  db_collation = "en_US.UTF8"

  user_name     = var.visit_manager_postgres_root_user
  user_password = coalesce(var.visit_manager_postgres_root_password, random_password.visit_manager_postgres_generated_password_root[0].result)

  additional_users = [
    {
      name            = var.visit_manager_postgres_user
      password        = coalesce(var.visit_manager_postgres_root_password, random_password.visit_manager_postgres_generated_password_root[0].result)
      random_password = false
    },
  ]

  depends_on = [ google_service_networking_connection.default ]
}

resource "random_password" "visit_manager_postgres_generated_password_root" {
  count = var.visit_manager_postgres_root_password == null ? 1 : 0
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "visit_manager_postgres_generated_password_user" {
  count = var.visit_manager_postgres_user_password == null ? 1 : 0
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}
