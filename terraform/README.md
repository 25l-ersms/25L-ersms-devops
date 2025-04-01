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

##### Prerequisite - connect to bastion host

```shell
gcloud compute ssh --zone "<REGION>-a" "<RESOURCE_PREFIX>--bastion" --project "<PROJECT_ID>" -- -p 2222
```

##### Kafka

Based on [quickstart guide](https://cloud.google.com/managed-service-for-apache-kafka/docs/quickstart).

**FROM BASTION HOST**.

Setup kafka command line tools:

```shell
export PROJECT_ID=<PROJECT_ID>
export REGION=<REGION>
export CLUSTER_ID=<RESOURCE_PREFIX>-kafka

sudo apt-get install default-jre wget unzip

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
kafka-topics.sh --list \
--bootstrap-server $BOOTSTRAP \
--command-config client.properties
```

##### PostgreSQL

**FROM BASTION HOST** - `psql` is pre-installed.

Get postgres IP:

```shell
terraform output postgres_ip
```

```shell
psql -h <POSTGRES_IP> -U <root|user> -d visit_manager --password
```

Supply the password via `stdin`. You can get it from terraform output: `terraform output postgres_<root|user>_password`. 

From `psql` shell:

```sql
SELECT datname FROM pg_database;
```

##### GKE cluster

***FROM BASTION HOST***

Fetch GKE credentials:

```shell
gcloud container clusters get-credentials ersms-test-gke --region=<REGION>-a --project=<PROJECT_ID>
```

Interact with the cluster using `kubectl`:

```shell
kubectl get pods --all-namespaces
```

Clone sample configs from cloud storage and apply them:

```shell
gcloud storage cp --recursive <RESOURCE_PREFIX>-k8s-manifests .
kubectl apply -f <RESOURCE_PREFIX>-k8s-manifests/
```

You can use the `debug-sdk` pod to test access to resources which require specific IAM roles:

```shell
kubectl exec -it debug-sdk -- bash
```

##### ElasticSearch

Access elasticsearch host:

```shell
# gcloud-cli does not provide a straightforward way to do proxyjumps
eval $(ssh-agent)
# gcloud's default key has the same password as host's user account
ssh-add ~/.ssh/google_compute_engine
ssh "$(whoami)@$(terraform output -raw elasticsearch_private_ip)" -p 22 -J "$(terraform output -raw bastion_ip):2222"
```

Authenticate and query cluster metadata:

// todo substitute terraform

```shell
sudo curl --cacert /etc/elasticsearch/certs/http_ca.crt -u "elastic:$(gcloud secrets versions access latest --secret=elasticsearch-root-password)" https://elasticsearch.vpc.internal:9200
```

You can do the same from the `debug-sdk` pod running on GKE:

```shell
gcloud secrets versions access latest --secret=elasticsearch-cacert --out-file=/tmp/es_ca.crt
curl --cacert /tmp/es_ca.crt -u "elastic:$(gcloud secrets versions access latest --secret=elasticsearch-root-password)" https://elasticsearch.vpc.internal:9200
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
