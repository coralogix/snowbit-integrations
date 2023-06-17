terraform {
  required_version = "~> 1.4"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.3.2"
    }
  }
}
provider "google" {
  project = var.gcp_project_id
  zone    = var.gcp_zone
}

### DATA
data "google_compute_subnetwork" "this" {
  name    = var.gcp_project_subnetwork_vpc
  project = ""
}
data "google_project" "current" {
  project_id = var.gcp_project_id
}

#### LOCAL
locals {
  domain_endpoint_map = {
    Europe    = "coralogix.com"
    Europe2   = "eu2.coralogix.com"
    India     = "app.coralogix.in"
    US        = "coralogix.us"
    Singapore = "coralogixsg.com"
  }
  user_pass    = replace(var.coralogix_private_key, "-", "")
  to_user_data = {
    docker = {
      install                  = <<EOF
sudo apt-get remove docker docker-engine docker.io containerd runc
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg lsb-release -y
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker
EOF
      image_pull               = <<EOF
docker pull coralogixrepo/coralogix-audit-collector
EOF
      google_workspace_command = <<EOF
# Google Workspace
crontab -l | { cat; echo "* * * * * docker run -it -e CORALOGIX_LOG_URL="https://ingress.${local.domain_endpoint_map[var.coralogix_domain]}/api/v1/logs" -e GOOGLE_TARGET_PRINCIPAL="${google_service_account.this.email}" -e CORALOGIX_PRIVATE_KEY="${var.coralogix_private_key}" -e CORALOGIX_APP_NAME="${var.coralogix_applicationName}" -e INTEGRATION_SEARCH_DIFF_IN_MINUTES="5" -e INTEGRATION_NAME="googleworkspace" -e IMPERSONATE_USER_EMAIL="${var.google_workspace_primary_admin_email_address}" -e BASE_URL="$BASE_URL" coralogixrepo/coralogix-audit-collector"; } | crontab -
EOF
    }
  }
}

resource "google_compute_instance" "this" {
  machine_type = var.gcp_machine_type
  name         = "coralogix-audit-collector"
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
      type  = var.gcp_boot_disk_type
    }
    kms_key_self_link = var.gcp_instance_kms_key_self_link
  }
  service_account {
    email  = google_service_account.this.email
    scopes = ["cloud-platform"]
  }
  shielded_instance_config {
    enable_vtpm                 = var.gcp_instance_enable_vtpm
    enable_secure_boot          = var.gcp_instance_enable_secure_boot
    enable_integrity_monitoring = var.gcp_instance_enable_integrity_monitoring
  }
  metadata = {
    block-project-ssh-keys = var.gcp_block_project_ssh_keys
  }
  metadata_startup_script = <<EOF
#!/bin/bash
apt-get update
echo -e "${local.user_pass}\n${local.user_pass}" | /usr/bin/passwd ubuntu

${local.to_user_data.docker.install}
${local.to_user_data.docker.image_pull}
${local.to_user_data.docker.google_workspace_command}

EOF
  network_interface {
    network    = data.google_compute_subnetwork.this.network
    subnetwork = var.gcp_project_subnetwork_vpc
    access_config {}
  }
}
resource "google_service_account_iam_binding" "this" {
  role               = google_project_iam_custom_role.this.name
  service_account_id = google_service_account.this.id
  members            = [
    "allAuthenticatedUsers"
  ]
}
resource "google_service_account" "this" {
  account_id   = "google-workspace-sa-${random_string.id.id}"
  display_name = "google-workspace-integration"
}
resource "google_project_iam_custom_role" "this" {
  permissions = ["iam.serviceAccounts.signJwt"]
  role_id     = "google_workspace_${random_string.id.id}"
  title       = "google-workspace-${random_string.id.id}"
}
resource "google_project_service" "admin_sdk" {
  service = "admin.googleapis.com"
  project = data.google_project.current.id
}
resource "random_string" "id" {
  length  = 8
  upper   = false
  special = false
}
