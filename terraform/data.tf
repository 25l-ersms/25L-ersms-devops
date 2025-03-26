data "google_client_config" "this" {}

data "http" "caller_ip_response" {
  url = "https://ifconfig.me/ip"
}

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
apt-get update

# Install tools
DEBIAN_FRONTEND=noninteractive apt-get install -y kubectl postgresql-client-16 postgresql-client-common
EOF
}
