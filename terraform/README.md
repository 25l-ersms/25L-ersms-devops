# ERSMS

### Prerequisites

`gcloud` CLI authenticated and pointing to the desired project.

### Setup

```shell
chmod +x setup.sh
./setup.sh
```

### Init

```shell
terraform apply
```

### Test the setup

##### Prerequisite - connect to bastion host

```shell
gcloud compute ssh --zone "<REGION-a" "<RESOURCE_PREFIX>--bastion" --project "<PROJECT_ID>" -- -p 2222
```

##### Kafka

Based on [quickstart guide](https://cloud.google.com/managed-service-for-apache-kafka/docs/quickstart).

**FROM BASTION HOST**.

Setup kafka command line tools:

```shell
export PROJECT_ID=<PROJECT_ID>
export CLUSTER_ID=<RESOURCE_PREFIX>-kafka

sudo apt-get install default-jre wget

wget -O kafka_2.13-3.7.2.tgz  https://downloads.apache.org/kafka/3.7.2/kafka_2.13-3.7.2.tgz
tar xfz kafka_2.13-3.7.2.tgz
export KAFKA_HOME=$(pwd)/kafka_2.13-3.7.2
export PATH=$PATH:$KAFKA_HOME/bin

wget https://github.com/googleapis/managedkafka/releases/download/v1.0.5/release-and-dependencies.zip
sudo apt-get install unzip
unzip -n -j release-and-dependencies.zip -d $KAFKA_HOME/libs/

cat <<EOF> client.properties
security.protocol=SASL_SSL
sasl.mechanism=OAUTHBEARER
sasl.login.callback.handler.class=com.google.cloud.hosted.kafka.auth.GcpLoginCallbackHandler
sasl.jaas.config=org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required;
EOF

export BOOTSTRAP=bootstrap.$CLUSTER_ID.us-central1.managedkafka.$PROJECT_ID.cloud.goog:9092
```

Access Kafka (eg. list topics, refer to guide for more operations). Bastion host is configured with `roles/managedkafka.viewer` and `roles/managedkafka.client` IAM roles, which should be enough to test whether the cluster is reachable.

```shell
kafka-topics.sh --list \
--bootstrap-server $BOOTSTRAP \
--command-config client.properties
```

##### PostgreSQL

**FROM BASTION HOST** - `psql` is pre-installed.

```shell
psql -h 10.240.0.3 -U root -d visit_manager --password
```

From `psql` shell:

```sql
SELECT datname FROM pg_database;
```
