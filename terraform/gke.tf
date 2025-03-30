module "gke" {
  source                     = "terraform-google-modules/kubernetes-engine/google//modules/private-cluster"
  project_id                 = local.gcp_project_id
  name                       = "${local.prfx}gke"
  region                     = local.gcp_region
  regional = false  # zonal cluster
  kubernetes_version = "1.32.2"
  zones                      = ["${local.gcp_region}-a"]
  network                    = module.vpc.network_name
  subnetwork                 = module.vpc.subnets["${local.gcp_region}/${var.resource_prefix}-private-subnet"].name
  ip_range_pods              = local.vpc_ip_range_gke_pods
  ip_range_services          = local.vpc_ip_range_gke_services
  http_load_balancing        = false
  network_policy             = false
  horizontal_pod_autoscaling = true
  filestore_csi_driver       = false
  enable_private_nodes       = true
  enable_identity_service    = true
  enable_secret_manager_addon = true
  dns_cache                  = false

  deletion_protection = false

  enable_private_endpoint    = true
  private_endpoint_subnetwork = module.vpc.subnets["${local.gcp_region}/${var.resource_prefix}-private-subnet"].name

  logging_enabled_components = [
    "SYSTEM_COMPONENTS",
    "WORKLOADS"
  ]
  logging_service = "logging.googleapis.com/kubernetes"

  monitoring_enable_managed_prometheus = true
  monitoring_enabled_components = [
    "SYSTEM_COMPONENTS",
    "POD",
    "DAEMONSET",
    "DEPLOYMENT",
    "STATEFULSET"
  ]
  monitoring_metric_writer_role = "roles/monitoring.metricWriter"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  node_pools = [
    {
      name                        = "default-node-pool"
      machine_type                = "e2-medium"
      node_locations              = "${local.gcp_region}-a"
      min_count                   = 1
      max_count                   = 3
      local_ssd_count             = 0
      spot                        = false
      disk_size_gb                = 50
      disk_type                   = "pd-standard"
      image_type                  = "COS_CONTAINERD"
      enable_gcfs                 = false
      enable_gvnic                = false
      logging_variant             = "DEFAULT"
      auto_repair                 = true
      auto_upgrade                = true
      # service_account             = google_service_account.gke_service_account.email
      preemptible                 = false
      initial_node_count          = 2
    },
  ]

  # TODO too permissive
  node_pools_oauth_scopes = {
    "all": [
        "https://www.googleapis.com/auth/cloud-platform"
        ]
  }


  master_authorized_networks = [
    {
      cidr_block   = local.vpc_private_cidr
      display_name = "VPC"
    },
  ]
}
