# ERSMS

### Prerequisites

- Google Cloud project with billing enabled ([guide](https://developers.google.com/workspace/guides/create-project))
- `gcloud` CLI authenticated and pointing to the desired project.

### Setup

```shell
chmod +x setup.sh
./setup.sh
```

### Create infrastructure

```shell
terraform apply
```

### Test the setup

// TODO automate this

##### Connect to bastion host

```shell
gcloud compute ssh --zone "<REGION>-a" "<RESOURCE_PREFIX>-bastion" --project "<PROJECT_ID>" -- -p 2222
```

##### GKE cluster

Get GKE cluster name: `terraform output gke_cluster_name`

Fetch GKE credentials:

```shell
# FROM BASTION HOST

gcloud container clusters get-credentials ersms-test-gke --region=<REGION>-a --project=<PROJECT_ID>
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

##### Use the debug pod

You can use the `debug-sdk` pod to test access to resources which require specific IAM roles:

```shell
# FROM BASSTION HOST

kubectl exec -it debug-sdk -- bash
```

You should be able to complete all of the following checks from both the bastion host and the debug pod.

##### Kafka

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

##### PostgreSQL

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

##### ElasticSearch

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

### Troubleshooting 

#### Resource already being used when executing `terraform destroy`

Example error message:

> Error when reading or editing Subnetwork: googleapi: Error 400: The subnetwork resource '<...>/subnetworks/<...>-private-subnet'' is already being used by '<...>/forwardingRules/<...>', resourceInUseByAnotherResource

- Go to https://console.cloud.google.com/net-services/loadbalancing/list/loadBalancers and delete all load balancers
- Go to https://console.cloud.google.com/net-security/firewall-manager/firewall-policies/list and delete all firewall rules **which do not start with _default_**
- Go to https://console.cloud.google.com/compute/networkendpointgroups/list and delete all network endpoint groups

#### API has not been used in project before or it is disabled

Example error message: 

> Error: Error creating service account: googleapi: Error 403: <...> API has not been used in project [PROJECT-NUMBER] before or it is disabled. Enable it by visiting https://console.developers.google.com/apis/api/iam.googleapis.com/overview?project=[PROJECT-NUMBER] then retry. If you enabled this API recently, wait a few minutes for the action to propagate to our systems and retry., accessNotConfigured

- If you have not ran `setup.sh` yet, now it's time to do it (the script is idempotent, you can re-run it anytime)
- Otherwise, just wait a few minutes :/ some APIs need a few minutes to *actually* become accessible despite showing up as enabled