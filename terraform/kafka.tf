# https://medium.com/google-cloud/local-development-with-google-cloud-managed-service-for-apache-kafka-8a50b2efb5ab
# ^ we need to manually configure gcloud cli, grab credentials file, base64 it and pass it to kafka
# username can be simply obtained from `gcloud auth list`
# also, bootstrap endpoint probably needs to be obtained from API using local-exec...
# kcat command:
#
# kcat -b <BOOTSTRAP HOSTNAME> \
# -X security.protocol=sasl_ssl -X sasl.mechanisms=PLAIN \
# -X sasl.username=<USER ACCOUNT> \
# -X sasl.password=<B64_ENCODED_CREDS_FILE> \
# -L -t <RES_PREFIX>-dummy-topic

resource "google_managed_kafka_cluster" "example" {
  cluster_id = "${local.prfx}kafka"
  location = local.gcp_region
  capacity_config {
    vcpu_count = 3
    memory_bytes = 3221225472
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
  topic_id = "${local.prfx}dummy-topic"
  cluster = google_managed_kafka_cluster.example.cluster_id
  location = local.gcp_region
  partition_count = 2
  replication_factor = 3
  configs = {
    "cleanup.policy" = "compact"
  }
}
