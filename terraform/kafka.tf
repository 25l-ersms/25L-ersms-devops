resource "google_managed_kafka_cluster" "kafka" {
  cluster_id = "${local.prfx}kafka"
  location   = local.gcp_region
  project    = local.gcp_project_id

  capacity_config {
    vcpu_count   = var.kafka_vpcu_count
    memory_bytes = var.kafka_memory_bytes
  }
  gcp_config {
    access_config {
      network_configs {
        subnet = module.vpc.subnets["${local.gcp_region}/${var.resource_prefix}-private-subnet"].id
      }
    }
  }
  rebalance_config {
    mode = "NO_REBALANCE"
  }
}

resource "google_managed_kafka_topic" "dummy" {
  topic_id           = "test_topic"
  cluster            = google_managed_kafka_cluster.kafka.cluster_id
  location           = local.gcp_region
  partition_count    = 2
  replication_factor = 3
  configs = {
    "cleanup.policy" = "compact"
  }
}
