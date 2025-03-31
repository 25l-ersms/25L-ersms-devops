data "google_client_config" "this" {}

data "google_project" "this" {}

data "http" "caller_ip_response" {
  url = "https://ifconfig.me/ip"
}

# TODO only run once with cloud-init
resource "terraform_data" "bastion_startup_script" {
  input = <<EOF
#!/bin/bash

set -x

# Move SSH to non-standard port
echo "Port ${var.bastion_ssh_port}" > /etc/ssh/sshd_config.d/10-port.conf
systemctl daemon-reload
systemctl restart ssh

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl gnupg

# Add k8s repo
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
chmod 644 /etc/apt/sources.list.d/kubernetes.list

# Add gcloud repo
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

apt-get update

# Install tools
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    kubectl \
    postgresql-client-16 \
    postgresql-client-common \
    kafkacat \
    google-cloud-sdk-gke-gcloud-auth-plugin
EOF
}

# TODO only run once with cloud-init
resource "terraform_data" "elasticsearch_startup_script" {
  input = <<EOF
#!/bin/bash

set -x

wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
DEBIAN_FRONTEND=noninteractive apt-get install -y apt-transport-https
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-8.x.list
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y elasticsearch

# allow inbound connections
sed -i "s/^#network\.host:.*$/network.host: 0.0.0.0/m" /etc/elasticsearch/elasticsearch.yml
# prevent other nodes from joining
echo "discovery.type: single-node" | tee -a /etc/elasticsearch/elasticsearch.yml
sed -E "s/^(discovery\.seed_hosts:.*)$/#\1/m" -i /etc/elasticsearch/elasticsearch.yml
sed -E "s/^(cluster\.initial_master_nodes:.*)$/#\1/m" -i /etc/elasticsearch/elasticsearch.yml

systemctl daemon-reload
systemctl enable elasticsearch.service
systemctl start elasticsearch.service

# set root user password
# FIXME startup script logs use xtrace, which leaks the password (lol)
elastic_password=$(gcloud secrets versions access latest --secret=${google_secret_manager_secret.elasticsearch_root_password.secret_id})
/usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic -i <<< "y
$elastic_password
$elastic_password
"

systemctl daemon-reload
systemctl restart elasticsearch.service

# upload the self-signed cert to the secret manager
gcloud secrets versions add ${google_secret_manager_secret.elasticsearch_cacert.secret_id} --data-file=/etc/elasticsearch/certs/http_ca.crt
EOF
}
