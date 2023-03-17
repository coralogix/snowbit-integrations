# GCP Variables --->
variable "existing_project_id" {
  type        = string
  description = "GCP project name"
  default = ""
}
variable "service_account_display_name" {
  type = string
}
variable "new_project_name" {
  default = ""
  type    = string
}
variable "new_project_organization" {
  default = ""
  type    = string
}
variable "new_project_billing_account" {
  default = ""
  type    = string
}
variable "machine_type" {
  type    = string
}
variable "boot_disk_type" {
  type    = string
  validation {
    condition     = var.boot_disk_type == "" ? true : can(regex("^(pd-balanced|pd-standard|pd-ssd|pd-extreme)$", var.boot_disk_type))
    error_message = "Invalid dick type"
  }
}
variable "gcp_instance_zone" {
  type = string
  default = "us-central1-a"
}

# GCP Data --->
data "google_project" "existing" {
  count = var.existing_project_id == "" ? 0 : 1
  project_id = var.existing_project_id
}
# GCP Resources --->
resource "google_project" "new_project" {
  count           = length(var.new_project_name) > 0 ? 1 : 0
  name            = var.new_project_name
  project_id      = "${lower(join("-",split(" ",var.new_project_name)))}-${random_string.id.id}"
  org_id          = var.new_project_organization
  billing_account = var.new_project_billing_account
  auto_create_network = true
}
resource "google_service_account" "service_account" {
  display_name = var.service_account_display_name
  account_id   = "${lower(join("-",split(" ",var.service_account_display_name)))}-${random_string.id.id}"
  project      = length(var.existing_project_id) > 0 ? var.existing_project_id : google_project.new_project[0].project_id
}
resource "google_service_account_key" "service_account_key" {
  service_account_id = google_service_account.service_account.id
  public_key_type    = "TYPE_X509_PEM_FILE"
}
resource "google_project_service" "workspaces_APIs" {
  for_each = {
    "Admin_SDK": "admin.googleapis.com",
    "Contacts_API": "contacts.googleapis.com",
    "Google_Workspace_Migrate_API": "migrate.googleapis.com",
    "Gmail_API": "gmail.googleapis.com",
    "Google_Calendar_API": "calendar-json.googleapis.com",
    "Google_Drive_API": "drive.googleapis.com",
    "Groups_Migration_API": "groupsmigration.googleapis.com",
    "Groups_Settings_API": "groupssettings.googleapis.com",
    "Google_Sheets_API": "sheets.googleapis.com",
    "Tasks_API": "tasks.googleapis.com"
  }
  service = each.value
  project = length(var.existing_project_id) > 0 ? var.existing_project_id : google_project.new_project[0].project_id
}
resource "google_project_service" "Compute_Engine_API" {
  count = var.instance_cloud_provider == "GCP" ? 1 : 0
  service = "compute.googleapis.com"
  project = length(var.existing_project_id) > 0 ? var.existing_project_id : google_project.new_project[0].project_id
}
resource "google_compute_instance" "this" {
  count = var.instance_cloud_provider == "GCP" ? 1 : 0
  depends_on = [google_project_service.Compute_Engine_API]
  project = length(var.existing_project_id) > 0 ? var.existing_project_id : google_project.new_project[0].project_id
  machine_type = length(var.machine_type) > 0 ? var.machine_type : "e2-highcpu-2"
  zone = var.gcp_instance_zone
  name         = "google-workspace-to-coralogix"
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
      type  = length(var.boot_disk_type) > 0 ? var.boot_disk_type : "pd-balanced"
    }
  }
  network_interface {
    network = "default"
    access_config {}
  }
  metadata_startup_script = <<EOT
#!/bin/bash
apt update
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.6.2-amd64.deb
sudo dpkg -i filebeat-8.6.2-amd64.deb
rm filebeat-8.6.2-amd64.deb
mkdir /etc/filebeat/certs
cd /etc/filebeat/certs
wget ${lookup(var.filebeat_certificates_map_url, var.coralogix_domain)}${lookup(var.filebeat_certificate_map_file_name, var.coralogix_domain)}
cd /etc/filebeat
echo '${base64decode(google_service_account_key.service_account_key.private_key)}' > google_credential_file.json
echo 'ignore_older: 3h
filebeat.modules:
- module: google_workspace
  saml:
    enabled: true
    var.jwt_file: "/etc/filebeat/google_credential_file.json"
    var.delegated_account: "${var.primary_google_workspace_admin_email_address}"
  user_accounts:
    enabled: true
    var.jwt_file: "/etc/filebeat/google_credential_file.json"
    var.delegated_account: "${var.primary_google_workspace_admin_email_address}"
  login:
    enable: true
    var.jwt_file: "/etc/filebeat/google_credential_file.json"
    var.delegated_account: "${var.primary_google_workspace_admin_email_address}"
  admin:
    enabled: true
    var.jwt_file: "/etc/filebeat/google_credential_file.json"
    var.delegated_account: "${var.primary_google_workspace_admin_email_address}"
  drive:
    enabled: true
    var.jwt_file: "/etc/filebeat/google_credential_file.json"
    var.delegated_account: "${var.primary_google_workspace_admin_email_address}"
  groups:
    enabled: true
    var.jwt_file: "/etc/filebeat/google_credential_file.json"
    var.delegated_account: "${var.primary_google_workspace_admin_email_address}"

processors:
  - drop_fields:
      fields: ["event.origin"]
      ignore_missing: true

fields_under_root: true
fields:
  PRIVATE_KEY: "${var.coralogix_private_key}"
  COMPANY_ID: ${var.coralogix_company_id}
  APP_NAME: "${var.coralogix_application_name}"
  SUB_SYSTEM: "${var.coralogix_subsystem_name}"

logging:
  level: debug
  to_files: true
  files:
  path: /var/log/filebeat
  name: filebeat.log
  keepfiles: 10
  permissions: 0644

output.logstash:
  enabled: true
  hosts: ["${lookup(var.logstash_map, var.coralogix_domain)}:5015"]
  tls.certificate_authorities: ["/etc/filebeat/certs/${lookup(var.filebeat_certificate_map_file_name, var.coralogix_domain)}"]
  ssl.certificate_authorities: ["/etc/filebeat/certs/${lookup(var.filebeat_certificate_map_file_name, var.coralogix_domain)}"]' > filebeat.yml
systemctl restart filebeat.service
EOT
}
resource "random_string" "id" {
  length  = 6
  upper   = false
  special = false
}