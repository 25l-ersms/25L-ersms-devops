module "gke" {
  source             = "terraform-google-modules/kubernetes-engine/google//modules/private-cluster"
  version            = "~> 36.1"
  project_id         = local.gcp_project_id
  name               = "${local.prfx}gke"
  region             = local.gcp_region
  kubernetes_version = "1.32"

  enterprise_config = "STANDARD"
  datapath_provider = "ADVANCED_DATAPATH"

  # networking
  # regional=false implies a zonal cluster
  regional                    = false
  zones                       = ["${local.gcp_region}-a"]
  network                     = module.vpc.network_name
  subnetwork                  = module.vpc.subnets["${local.gcp_region}/${var.resource_prefix}-private-subnet"].name
  ip_range_pods               = local.vpc_ip_range_gke_pods
  ip_range_services           = local.vpc_ip_range_gke_services
  enable_private_endpoint     = true
  private_endpoint_subnetwork = module.vpc.subnets["${local.gcp_region}/${var.resource_prefix}-private-subnet"].name
  master_authorized_networks = [
    {
      cidr_block   = local.vpc_private_cidr
      display_name = "VPC"
    },
    {
      cidr_block   = "${google_compute_instance.bastion.network_interface[0].network_ip}/32"
      display_name = "bastion"
    },
  ]
  cluster_dns_domain   = "${local.prfx}gke"
  cluster_dns_provider = "CLOUD_DNS"
  cluster_dns_scope    = "VPC_SCOPE"
  # required for DNS endpoint... epic bruh moment
  # https://github.com/terraform-google-modules/terraform-google-kubernetes-engine/blob/v36.1.0/modules/private-cluster/cluster.tf#L533
  deploy_using_private_endpoint = true

  # addons
  http_load_balancing         = true
  network_policy              = false
  horizontal_pod_autoscaling  = true
  filestore_csi_driver        = false
  enable_private_nodes        = true
  enable_identity_service     = true
  enable_secret_manager_addon = true
  dns_cache                   = false
  gateway_api_channel         = "CHANNEL_STANDARD"

  deletion_protection = false

  # observability
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
  monitoring_service            = "monitoring.googleapis.com/kubernetes"

  # nodes
  node_pools = [
    {
      name               = "${local.prfx}default-node-pool"
      machine_type       = var.gke_instance_size
      node_locations     = "${local.gcp_region}-a"
      min_count          = var.gke_min_nodes
      max_count          = var.gke_max_nodes
      local_ssd_count    = 0
      spot               = false
      disk_size_gb       = 50
      disk_type          = "pd-standard"
      image_type         = "COS_CONTAINERD"
      enable_gcfs        = false
      enable_gvnic       = false
      logging_variant    = "DEFAULT"
      auto_repair        = true
      auto_upgrade       = true
      preemptible        = false
      initial_node_count = var.gke_initial_nodes
    },
  ]

  node_pools_oauth_scopes = {
    "all" : [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

resource "google_compute_global_address" "ingress_external_alb_ip" {
  name = "${local.prfx}ingress-external-alb-ipv4"
}


resource "google_compute_ssl_policy" "modern-profile" {
  name            = "${local.prfx}ssl-policy"
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"
}
