# TODO DNS
# TODO authenticate using IAM

module "pg" {
  source  = "terraform-google-modules/sql-db/google//modules/postgresql"
  version = "~> 25.2"

  name                 = "${local.prfx}visit-manager-postgres"
  random_instance_name = true
  project_id           = local.gcp_project_id
  database_version     = var.visit_manager_postgres_version
  region               = local.gcp_region
  edition              = "ENTERPRISE"

  tier                            = var.visit_manager_postgres_instance_size
  zone                            = "${local.gcp_region}-a"
  availability_type               = "ZONAL"
  maintenance_window_day          = 7
  maintenance_window_hour         = 12
  maintenance_window_update_track = "stable"

  deletion_protection = false



  ip_configuration = {
    ipv4_enabled        = false
    # can also be ENCRYPTED_ONLY
    ssl_mode            = "ALLOW_UNENCRYPTED_AND_ENCRYPTED" 
    private_network     = module.vpc.network_self_link
    allocated_ip_range  = google_compute_global_address.private_ip_alloc.name
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

  depends_on = [google_service_networking_connection.default]
}

