# ERSMS terraform

![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white) ![Google Cloud](https://img.shields.io/badge/GoogleCloud-%234285F4.svg?style=for-the-badge&logo=google-cloud&logoColor=white)

## Prerequisites

- Google Cloud project with billing enabled ([guide](https://developers.google.com/workspace/guides/create-project))
- `gcloud` CLI authenticated and pointing to the desired project.
  - `gcloud config set project <PROJECT_ID>`
  - `gcloud auth application-default login`
- [`terraform`](https://developer.hashicorp.com/terraform/install?product_intent=terraform) version `>=1.10.0`
- For development:
  - [`pre-commit`](https://pre-commit.com/)
  - [`tflint`](https://github.com/terraform-linters/tflint)
  - [`terraform-docs`](https://terraform-docs.io/)

## Setup

```shell
chmod +x setup.sh
./setup.sh
```

If you plan to make any changes, install pre-commit hooks:

```shell
pre-commit install
```

## Create infrastructure

```shell
terraform apply
```

## Test the setup

// TODO automate this

#### Connect to bastion host

```shell
gcloud compute ssh --zone "<REGION>-a" "<RESOURCE_PREFIX>-bastion" --project "<PROJECT_ID>" -- -p 2222
```

#### GKE cluster

Get GKE cluster name: `terraform output gke_cluster_name`

Fetch GKE credentials:

```shell
# FROM BASTION HOST

gcloud container clusters get-credentials ersms-gke --region=<REGION>-a --project=<PROJECT_ID>
```

Interact with the cluster using `kubectl`:

```shell
# FROM BASTION HOST

kubectl get pods --all-namespaces
```

Get manifests bucket name: `terraform output storage_k8s_manifests_bucket_url`

Clone sample configs from cloud storage and apply them:

```shell
# FROM BASTION HOST

gcloud storage cp --recursive <MANIFESTS_BUCKET_NAME> .
kubectl apply -f <MANIFESTS_BUCKET_NAME>/
```

#### Use the debug pod

You can use the `debug-sdk` pod to test access to resources which require specific IAM roles:

```shell
# FROM BASTION HOST
kubectl exec -it debug-sdk -- bash
```

You should be able to complete all of the following checks from both the bastion host and the debug pod.

#### Kafka

Based on [quickstart guide](https://cloud.google.com/managed-service-for-apache-kafka/docs/quickstart).

Get Kafka cluster name: `terraform output kafka_cluster_id`

Setup Kafka command line tools:

```shell
# FROM BASTION HOST

export PROJECT_ID=<PROJECT_ID>
export REGION=<REGION>
export CLUSTER_ID=<KAFKA_CLUSTER_ID>

sudo apt-get install -y default-jre wget unzip

wget -O kafka_2.13-3.7.2.tgz  https://downloads.apache.org/kafka/3.7.2/kafka_2.13-3.7.2.tgz
tar xfz kafka_2.13-3.7.2.tgz
export KAFKA_HOME=$(pwd)/kafka_2.13-3.7.2
export PATH=$PATH:$KAFKA_HOME/bin

wget https://github.com/googleapis/managedkafka/releases/download/v1.0.5/release-and-dependencies.zip
unzip -n -j release-and-dependencies.zip -d $KAFKA_HOME/libs/

cat <<EOF> client.properties
security.protocol=SASL_SSL
sasl.mechanism=OAUTHBEARER
sasl.login.callback.handler.class=com.google.cloud.hosted.kafka.auth.GcpLoginCallbackHandler
sasl.jaas.config=org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required;
EOF

export BOOTSTRAP=bootstrap.$CLUSTER_ID.$REGION.managedkafka.$PROJECT_ID.cloud.goog:9092
```

Access Kafka (eg. list topics, refer to guide for more operations). Bastion host is configured with `roles/managedkafka.viewer` and `roles/managedkafka.client` IAM roles, which should be enough to test whether the cluster is reachable.

```shell
# FROM BASTION HOST

kafka-topics.sh --list \
--bootstrap-server $BOOTSTRAP \
--command-config client.properties
```

To test sending messages, open a `tmux` session and execute commands in two separate shells:

Listen to a topic:

```shell
kafka-console-consumer.sh --bootstrap-server $BOOTSTRAP --topic test_topic --consumer.config client.properties
```

Publish messages in a topic:

```shell
kafka-console-producer.sh --bootstrap-server $BOOTSTRAP --topic test_topic --producer.config client.properties --property parse.key=true --property key.separator=:
```

Send a "hello" message with a "test" key: enter "test:hello" in the producer session. The message should appear in the consumer window.

#### PostgreSQL

Get postgres IP, password and DB name:

```shell
terraform output postgres_ip
terraform output postgres_root_password
terraform output postgres_db_name
```

Connect to Cloud SQL running Postgres:

```shell
# FROM BASTION HOST

psql -h <POSTGRES_IP> -U root -d <DB_NAME> --password
```

Supply the password via `stdin`.

From `psql` shell:

```sql
SELECT datname FROM pg_database;
```

#### ElasticSearch

Get ElasticSearch DNS name, proto, port, cert secret id, root user username and password secret id:

```shell
terraform output elasticsearch_dns_name
terraform output elasticsearch_proto
terraform output elasticsearch_port
terraform output elasticsearch_caceret_secret_id
terraform output elasticsearch_root_username
terraform output elasticsearch_root_password_secret_id
```

Access ElasticSearch host:

```shell
# FROM YOUR MACHINE

# gcloud-cli does not provide a straightforward way to do proxyjumps
eval $(ssh-agent)
# gcloud's default key has the same password as host's user account
ssh-add ~/.ssh/google_compute_engine
ssh "$(whoami)@$(terraform output -raw elasticsearch_private_ip)" -p 22 -J "$(terraform output -raw bastion_ip):$(terraform output -raw bastion_ssh_port)"
```

Authenticate and query cluster metadata:

```shell
sudo curl --cacert /etc/elasticsearch/certs/http_ca.crt -u "<ES_USER>:$(gcloud secrets versions access latest --secret=<ES_PASSWORD_SECRET_ID>)" <ES_PROTO>://<ES_DNS_NAME>:<ES_PORT>
```

You can do the same from the `debug-sdk` pod running on GKE:

```shell
# FROM DEBUG POD

gcloud secrets versions access latest --secret=<ES_CERT_SECRET_ID> --out-file=/tmp/es_ca.crt
curl --cacert /tmp/es_ca.crt -u "<ES_USERNAME>:$(gcloud secrets versions access latest --secret=<ES_PASSWORD_SECRET_ID>)" <ES_PROTO>://<ES_DNS_NAME>:<ES_PORT>
```

#### Firestore

From bastion host / debug pod:

```shell
gcloud firestore databases list
```

## Troubleshooting

### Resource already being used when executing `terraform destroy`

Example error message:

> Error when reading or editing Subnetwork: googleapi: Error 400: The subnetwork resource '<...>/subnetworks/<...>-private-subnet'' is already being used by '<...>/forwardingRules/<...>', resourceInUseByAnotherResource

- Go to https://console.cloud.google.com/net-services/loadbalancing/list/loadBalancers and delete all load balancers
- Go to https://console.cloud.google.com/net-security/firewall-manager/firewall-policies/list and delete all firewall rules **which do not start with _default_**
- Go to https://console.cloud.google.com/compute/networkendpointgroups/list and delete all network endpoint groups

### API has not been used in project before or it is disabled

Example error message:

> Error: Error creating service account: googleapi: Error 403: <...> API has not been used in project [PROJECT-NUMBER] before or it is disabled. Enable it by visiting https://console.developers.google.com/apis/api/iam.googleapis.com/overview?project=[PROJECT-NUMBER] then retry. If you enabled this API recently, wait a few minutes for the action to propagate to our systems and retry., accessNotConfigured

- If you have not ran `setup.sh` yet, now it's time to do it (the script is idempotent, you can re-run it anytime)
- Otherwise, just wait a few minutes :/ some APIs need a few minutes to *actually* become accessible despite showing up as enabled

### Timeout when SSH-ing to bastion

Terraform creates a ~~security group~~ firewall rule which allows inbound TCP on port 2222 (default) **only from your current IP**. The IP is checked when applying the config. If you expect it could change, simply rerun `terraform apply`.

### Google could not find default credentials

Example error message:

> storage.NewClient() failed: dialing: google: could not find default credentials. See https://cloud.google.com/docs/authentication/external/set-up-adc for more information

Terraform's Google provider is configured to use default `gcloud` credentials. If you have not configured them, run `gcloud auth application-default login`.

### Service does not have permission to retrieve subnet

Example error message:

> Error creating Cluster: googleapi: Error 400: Invalid resource state for "projects/<PROJECT_ID>/regions/<REGION>/subnetworks/<SUBNET>": Service does not have permission to retrieve subnet. Please grant <SERVICE_ID(?)>@gcp-sa-managedkafka.iam.gserviceaccount.com the managedkafka.serviceAgent role in the IAM policy of the project <PROJECT_ID> and ensure the Compute Engine API is enabled in project <PROJECT_ID>

Honestly, I have no idea what causes this issue. It appeared in my environment randomly when I was messing with Managed Kafka. Doing what the message says seems do resolve the issue:

```shell
gcloud projects add-iam-policy-binding <PROJECT_ID> \
   --member="serviceAccount:<SERVICE_ID(?)>@gcp-sa-managedkafka.iam.gserviceaccount.com" \
   --role="roles/managedkafka.serviceAgent"
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_cloudinit"></a> [cloudinit](#requirement\_cloudinit) | ~> 2.3 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 6.8 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | ~> 6.27 |
| <a name="requirement_http"></a> [http](#requirement\_http) | ~> 3.4 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.7 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | 6.27.0 |
| <a name="provider_http"></a> [http](#provider\_http) | 3.4.5 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.1 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cloud-nat-group1"></a> [cloud-nat-group1](#module\_cloud-nat-group1) | terraform-google-modules/cloud-nat/google | ~> 5.0 |
| <a name="module_gke"></a> [gke](#module\_gke) | terraform-google-modules/kubernetes-engine/google//modules/private-cluster | ~> 36.1 |
| <a name="module_pg"></a> [pg](#module\_pg) | terraform-google-modules/sql-db/google//modules/postgresql | ~> 25.2 |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-google-modules/network/google | ~> 10.0 |

## Resources

| Name | Type |
|------|------|
| [google_compute_address.bastion_ip](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address) | resource |
| [google_compute_firewall.bastion_inbound](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.bastion_outbound_elasticsearch](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.bastion_outbound_postgres](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.elasticsearch_inbound_https_bastion](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.elasticsearch_inbound_https_gke](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.elasticsearch_inbound_ssh](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.gke_to_es_outbound](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.vpc_private_internal](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_global_address.ingress_external_alb_ip](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address) | resource |
| [google_compute_global_address.private_ip_alloc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address) | resource |
| [google_compute_instance.bastion](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |
| [google_compute_instance.elasticsearch](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |
| [google_compute_router.group1](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router) | resource |
| [google_dns_managed_zone.internal-zone](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_managed_zone) | resource |
| [google_dns_record_set.elsasticsearch](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set) | resource |
| [google_firestore_database.database](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/firestore_database) | resource |
| [google_managed_kafka_cluster.kafka](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/managed_kafka_cluster) | resource |
| [google_managed_kafka_topic.dummy](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/managed_kafka_topic) | resource |
| [google_project_iam_binding.bastion_service_account_iam_binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_binding) | resource |
| [google_project_iam_binding.firestore_service_account_iam_binding_bastion](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_binding) | resource |
| [google_project_iam_binding.firestore_service_account_iam_binding_gke](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_binding) | resource |
| [google_project_iam_binding.gke_ingress_controller_iam_binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_binding) | resource |
| [google_project_iam_binding.gke_pod_identity_external_secrets_iam_binding1](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_binding) | resource |
| [google_project_iam_binding.gke_pod_identity_user_chat_iam_binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_binding) | resource |
| [google_project_iam_binding.kafka_service_account_iam_binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_binding) | resource |
| [google_secret_manager_secret.elasticsearch_cacert](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret.elasticsearch_root_password](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret.elasticsearch_root_user](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret.google_oauth2_client_id](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret.google_oauth2_client_secret](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret.jwt_secret_key](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret.postgres_root_password](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret.postgres_user_password](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret.secret_key](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret.stripe_api_key](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret_iam_binding.elasticsearch_cacert_elsasticsearch_secretaccessor_binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_iam_binding) | resource |
| [google_secret_manager_secret_iam_binding.elasticsearch_cacert_elsasticsearch_secretversionadder_binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_iam_binding) | resource |
| [google_secret_manager_secret_iam_binding.elasticsearch_root_password_elsasticsearch_secretaccessor_binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_iam_binding) | resource |
| [google_secret_manager_secret_iam_binding.elasticsearch_root_password_elsasticsearch_secretversionadder_binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_iam_binding) | resource |
| [google_secret_manager_secret_iam_binding.postgres_root_password_secretaccessor_binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_iam_binding) | resource |
| [google_secret_manager_secret_iam_binding.postgres_user_password_secretaccessor_binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_iam_binding) | resource |
| [google_secret_manager_secret_version.elasticsearch_root_password_initial](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_secret_manager_secret_version.elasticsearch_root_user_initial](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_secret_manager_secret_version.google_oauth2_client_id_initial](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_secret_manager_secret_version.google_oauth2_client_secret_initial](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_secret_manager_secret_version.jwt_secret_key_initial](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_secret_manager_secret_version.postgres_root_password_initial](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_secret_manager_secret_version.postgres_user_password_initial](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_secret_manager_secret_version.secret_key_initial](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_secret_manager_secret_version.stripe_api_key_initial](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_service_account.bastion_service_account](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account.elasticsearch_service_account](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account.gke_pod_identity](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account.gke_pod_identity_external_secrets](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account.gke_pod_identity_user_chat](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account.gke_pod_identity_visit_man](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account.gke_pod_identity_visit_sched](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account.gke_service_account](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_networking_connection.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_networking_connection) | resource |
| [google_storage_bucket.k8s_manifests](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_storage_bucket_object.k8s_debug_sdk](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_object) | resource |
| [google_storage_bucket_object.k8s_example](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_object) | resource |
| [random_password.elasticsearch_root_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_password.visit_manager_postgres_generated_password_root](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_password.visit_manager_postgres_generated_password_user](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [terraform_data.bastion_startup_script](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.elasticsearch_startup_script](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [google_client_config.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config) | data source |
| [google_project.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |
| [http_http.caller_ip_response](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bastion_instance_size"></a> [bastion\_instance\_size](#input\_bastion\_instance\_size) | Instance size of bastion machine | `string` | `"e2-micro"` | no |
| <a name="input_bastion_ssh_port"></a> [bastion\_ssh\_port](#input\_bastion\_ssh\_port) | Port for inbound SSH connections to bastion | `string` | `2222` | no |
| <a name="input_elasticsearch_instance_size"></a> [elasticsearch\_instance\_size](#input\_elasticsearch\_instance\_size) | Instance size of ES machine | `string` | `"e2-standard-2"` | no |
| <a name="input_gke_initial_nodes"></a> [gke\_initial\_nodes](#input\_gke\_initial\_nodes) | Initial number of nodes in GKE CLUSTER | `number` | `1` | no |
| <a name="input_gke_instance_size"></a> [gke\_instance\_size](#input\_gke\_instance\_size) | Instance size of nodes in GKE CLUSTER | `string` | `"e2-standard-2"` | no |
| <a name="input_gke_max_nodes"></a> [gke\_max\_nodes](#input\_gke\_max\_nodes) | Maximum number of nodes in GKE CLUSTER | `number` | `2` | no |
| <a name="input_gke_min_nodes"></a> [gke\_min\_nodes](#input\_gke\_min\_nodes) | Minimum number of nodes in GKE CLUSTER | `number` | `1` | no |
| <a name="input_kafka_memory_bytes"></a> [kafka\_memory\_bytes](#input\_kafka\_memory\_bytes) | Memory size in Kafka cluster | `number` | `3221225472` | no |
| <a name="input_kafka_vpcu_count"></a> [kafka\_vpcu\_count](#input\_kafka\_vpcu\_count) | Number of vCPUs in Kafka cluster | `number` | `3` | no |
| <a name="input_resource_prefix"></a> [resource\_prefix](#input\_resource\_prefix) | Prefix for all resources | `string` | n/a | yes |
| <a name="input_visit_manager_postgres_db_name"></a> [visit\_manager\_postgres\_db\_name](#input\_visit\_manager\_postgres\_db\_name) | Name of PostgreSQL DB for visit manager service | `string` | `"visit_manager"` | no |
| <a name="input_visit_manager_postgres_instance_size"></a> [visit\_manager\_postgres\_instance\_size](#input\_visit\_manager\_postgres\_instance\_size) | Postgres instance size | `string` | `"db-custom-1-3840"` | no |
| <a name="input_visit_manager_postgres_port"></a> [visit\_manager\_postgres\_port](#input\_visit\_manager\_postgres\_port) | Port for connections to DB for visit manager service | `string` | `"5432"` | no |
| <a name="input_visit_manager_postgres_root_password"></a> [visit\_manager\_postgres\_root\_password](#input\_visit\_manager\_postgres\_root\_password) | Root user passoword for visit manager PostgreSQL. A random password will be generated if not provided. | `string` | `null` | no |
| <a name="input_visit_manager_postgres_root_user"></a> [visit\_manager\_postgres\_root\_user](#input\_visit\_manager\_postgres\_root\_user) | Root username for visit manager PostgreSQL | `string` | `"root"` | no |
| <a name="input_visit_manager_postgres_user"></a> [visit\_manager\_postgres\_user](#input\_visit\_manager\_postgres\_user) | User username for visit manager PostgreSQL | `string` | `"user"` | no |
| <a name="input_visit_manager_postgres_user_password"></a> [visit\_manager\_postgres\_user\_password](#input\_visit\_manager\_postgres\_user\_password) | User passowrd for visit manager PostgreSQL. A random password will be generated if not provided. | `string` | `null` | no |
| <a name="input_visit_manager_postgres_version"></a> [visit\_manager\_postgres\_version](#input\_visit\_manager\_postgres\_version) | Major version od PostgreSQL to be used in visit manager service | `string` | `"16"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bastion_ip"></a> [bastion\_ip](#output\_bastion\_ip) | n/a |
| <a name="output_bastion_ssh_port"></a> [bastion\_ssh\_port](#output\_bastion\_ssh\_port) | n/a |
| <a name="output_elasticsearch_caceret_secret_id"></a> [elasticsearch\_caceret\_secret\_id](#output\_elasticsearch\_caceret\_secret\_id) | n/a |
| <a name="output_elasticsearch_dns_name"></a> [elasticsearch\_dns\_name](#output\_elasticsearch\_dns\_name) | n/a |
| <a name="output_elasticsearch_port"></a> [elasticsearch\_port](#output\_elasticsearch\_port) | n/a |
| <a name="output_elasticsearch_private_ip"></a> [elasticsearch\_private\_ip](#output\_elasticsearch\_private\_ip) | n/a |
| <a name="output_elasticsearch_proto"></a> [elasticsearch\_proto](#output\_elasticsearch\_proto) | n/a |
| <a name="output_elasticsearch_root_password"></a> [elasticsearch\_root\_password](#output\_elasticsearch\_root\_password) | n/a |
| <a name="output_elasticsearch_root_password_secret_id"></a> [elasticsearch\_root\_password\_secret\_id](#output\_elasticsearch\_root\_password\_secret\_id) | n/a |
| <a name="output_elasticsearch_root_username"></a> [elasticsearch\_root\_username](#output\_elasticsearch\_root\_username) | n/a |
| <a name="output_firestore_db_name"></a> [firestore\_db\_name](#output\_firestore\_db\_name) | n/a |
| <a name="output_gke_cluster_dns_endpoint"></a> [gke\_cluster\_dns\_endpoint](#output\_gke\_cluster\_dns\_endpoint) | n/a |
| <a name="output_gke_cluster_endpoint"></a> [gke\_cluster\_endpoint](#output\_gke\_cluster\_endpoint) | n/a |
| <a name="output_gke_cluster_name"></a> [gke\_cluster\_name](#output\_gke\_cluster\_name) | n/a |
| <a name="output_ingress_global_ip_address"></a> [ingress\_global\_ip\_address](#output\_ingress\_global\_ip\_address) | n/a |
| <a name="output_ingress_global_ip_name"></a> [ingress\_global\_ip\_name](#output\_ingress\_global\_ip\_name) | n/a |
| <a name="output_kafka_bootstrap_url"></a> [kafka\_bootstrap\_url](#output\_kafka\_bootstrap\_url) | according to https://cloud.google.com/managed-service-for-apache-kafka/docs/quickstart#use_the_kafka_command_line_tools |
| <a name="output_kafka_cluster_id"></a> [kafka\_cluster\_id](#output\_kafka\_cluster\_id) | n/a |
| <a name="output_postgres_db_name"></a> [postgres\_db\_name](#output\_postgres\_db\_name) | n/a |
| <a name="output_postgres_dns_name"></a> [postgres\_dns\_name](#output\_postgres\_dns\_name) | Enterprise plus is required... seriously, Google? https://cloud.google.com/sql/docs/mysql/instance-info#view-write-endpoint |
| <a name="output_postgres_ip"></a> [postgres\_ip](#output\_postgres\_ip) | n/a |
| <a name="output_postgres_root_password"></a> [postgres\_root\_password](#output\_postgres\_root\_password) | n/a |
| <a name="output_postgres_root_username"></a> [postgres\_root\_username](#output\_postgres\_root\_username) | n/a |
| <a name="output_postgres_user_password"></a> [postgres\_user\_password](#output\_postgres\_user\_password) | n/a |
| <a name="output_postgres_user_username"></a> [postgres\_user\_username](#output\_postgres\_user\_username) | n/a |
| <a name="output_project"></a> [project](#output\_project) | n/a |
| <a name="output_region"></a> [region](#output\_region) | n/a |
| <a name="output_storage_k8s_manifests_bucket_url"></a> [storage\_k8s\_manifests\_bucket\_url](#output\_storage\_k8s\_manifests\_bucket\_url) | n/a |
<!-- END_TF_DOCS -->
