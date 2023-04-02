variable "google_workspace_application_name" {
  type        = string
  description = "Coralogix application name for Google Workspace"
  default     = "Google_Workspace"
  validation {
    condition     = var.google_workspace_application_name == "" ? true : can(regex("^[A-Za-z0-9\\s\\-\\_]+$", var.google_workspace_application_name))
    error_message = "Invalid application name."
  }
}
variable "google_workspace_subsystem_name" {
  type = string
  description = "Coralogix subsystem name for Google Workspace"
  default     = "Google_Workspace"
  validation {
    condition     = var.google_workspace_subsystem_name == "" ? true : can(regex("^[A-Za-z0-9\\s\\-\\_]+$", var.google_workspace_subsystem_name))
    error_message = "Invalid subsystem name."
  }
}
variable "google_workspace_existing_project_id" {
  type        = string
  description = "GCP project name"
  default     = ""
  validation {
    condition = var.google_workspace_existing_project_id == "" ? true : can(regex("^[a-z][-a-z0-9]{4,28}[a-z0-9]{1}$", var.google_workspace_existing_project_id))
    error_message = "Invalid existing project ID."
  }
}
variable "google_workspace_service_account_display_name" {
  type = string
}
variable "google_workspace_new_project_name" {
  type    = string
  default = ""
}
variable "google_workspace_new_project_organization_id" {
  type    = string
  default = ""
  validation {
    condition = var.google_workspace_new_project_organization_id == "" ? true : can(regex("^\\d{12}$", var.google_workspace_new_project_organization_id))
    error_message = "Invalid organization ID."
  }
}
variable "google_workspace_new_project_billing_account_id" {
  type    = string
  default = ""
  validation {
    condition = var.google_workspace_new_project_billing_account_id == "" ? true : can(regex("^(?:[A-F0-9]{6}-){2}[A-F0-9]{6}$", var.google_workspace_new_project_billing_account_id))
    error_message = "Invalid billing account ID."
  }
}
variable "google_workspace_primary_admin_email_address" {
  type = string
  validation {
    condition     = var.google_workspace_primary_admin_email_address == "" ? true : can(regex("^[a-zA-Z0-9.!#$%&'*+\\/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\\.[a-zA-Z0-9-]+)$", var.google_workspace_primary_admin_email_address))
    error_message = "Invalid email address."
  }
}

locals {
  filebeat_certificate_map_file_name = {
    Europe    = "Coralogix-EU.crt"
    India     = "Coralogix-IN.pem"
    US        = "AmazonRootCA1.pem"
    Singapore = "AmazonRootCA1.pem"
  }
  filebeat_certificates_map_url = {
    Europe    = "https://coralogix-public.s3-eu-west-1.amazonaws.com/certificate/"
    India     = "https://coralogix-public.s3-eu-west-1.amazonaws.com/certificate/"
    US        = "https://www.amazontrust.com/repository/AmazonRootCA1.pem"
    Singapore = "https://www.amazontrust.com/repository/AmazonRootCA1.pem"
  }
  logstash_map = {
    Europe    = "logstashserver.coralogix.com"
    India     = "logstash.app.coralogix.in"
    US        = "logstashserver.coralogix.us"
    Singapore = "logstashserver.coralogixsg.com"
  }
  google_apis = {
    "Admin_SDK" : "admin.googleapis.com",
    "Contacts_API" : "contacts.googleapis.com",
    "Google_Workspace_Migrate_API" : "migrate.googleapis.com",
    "Gmail_API" : "gmail.googleapis.com",
    "Google_Calendar_API" : "calendar-json.googleapis.com",
    "Google_Drive_API" : "drive.googleapis.com",
    "Groups_Migration_API" : "groupsmigration.googleapis.com",
    "Groups_Settings_API" : "groupssettings.googleapis.com",
    "Google_Sheets_API" : "sheets.googleapis.com",
    "Tasks_API" : "tasks.googleapis.com"
  }
  google_workspace_conf      = <<EOF
ignore_older: 3h
filebeat.modules:
- module: google_workspace
  saml:
    enabled: true
    var.jwt_file: "/usr/share/filebeat/google_credential_file.json"
    var.delegated_account: "${var.google_workspace_primary_admin_email_address}"
  user_accounts:
    enabled: true
    var.jwt_file: "/usr/share/filebeat/google_credential_file.json"
    var.delegated_account: "${var.google_workspace_primary_admin_email_address}"
  login:
    enable: true
    var.jwt_file: "/usr/share/filebeat/google_credential_file.json"
    var.delegated_account: "${var.google_workspace_primary_admin_email_address}"
  admin:
    enabled: true
    var.jwt_file: "/usr/share/filebeat/google_credential_file.json"
    var.delegated_account: "${var.google_workspace_primary_admin_email_address}"
  drive:
    enabled: true
    var.jwt_file: "/usr/share/filebeat/google_credential_file.json"
    var.delegated_account: "${var.google_workspace_primary_admin_email_address}"
  groups:
    enabled: true
    var.jwt_file: "/usr/share/filebeat/google_credential_file.json"
    var.delegated_account: "${var.google_workspace_primary_admin_email_address}"

processors:
  - drop_fields:
      fields: ["event.origin"]
      ignore_missing: true

fields_under_root: true
fields:
  PRIVATE_KEY: "${var.coralogix_private_key}"
  COMPANY_ID: ${var.coralogix_company_id}
  APP_NAME: "${length(var.google_workspace_application_name) > 0 ? var.google_workspace_application_name : "Google-Workspace"}"
  SUB_SYSTEM: "${length(var.google_workspace_subsystem_name) > 0 ? var.google_workspace_subsystem_name : "Google-Workspace"}"

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
  hosts: ["${lookup(local.logstash_map, var.coralogix_domain)}:5015"]
  tls.certificate_authorities: ["/usr/share/filebeat/${lookup(local.filebeat_certificate_map_file_name, var.coralogix_domain)}"]
  ssl.certificate_authorities: ["/usr/share/filebeat/${lookup(local.filebeat_certificate_map_file_name, var.coralogix_domain)}"]
EOF
  google_workspace_user_data = <<EOF

#
# Google Workspace -->
#

mkdir /home/ubuntu/integrations/certs
wget -O /home/ubuntu/integrations/certs/${lookup(local.filebeat_certificate_map_file_name, var.coralogix_domain)} ${lookup(local.filebeat_certificates_map_url, var.coralogix_domain)}${lookup(local.filebeat_certificate_map_file_name, var.coralogix_domain)}
echo '${var.google_workspace_integration_required ? base64decode(google_service_account_key.service_account_key[0].private_key) : ""}' > /home/ubuntu/integrations/google_credential_file.json
echo '${local.google_workspace_conf}' > /home/ubuntu/integrations/google_workspace.yml
docker run -d --name google_workspace \
-v /home/ubuntu/integrations/certs/${lookup(local.filebeat_certificate_map_file_name, var.coralogix_domain)}:/usr/share/filebeat/${lookup(local.filebeat_certificate_map_file_name, var.coralogix_domain)} \
-v /home/ubuntu/integrations/google_workspace.yml:/usr/share/filebeat/filebeat.yml \
-v /home/ubuntu/integrations/google_credential_file.json:/usr/share/filebeat/google_credential_file.json \
docker.elastic.co/beats/filebeat:8.6.2
EOF
}

resource "google_project" "new_project" {
  count               = var.google_workspace_integration_required && length(var.google_workspace_new_project_name) > 0 ? 1 : 0
  name                = var.google_workspace_new_project_name
  project_id          = "${lower(join("-",split(" ",var.google_workspace_new_project_name)))}-${random_string.this[0].id}"
  org_id              = var.google_workspace_new_project_organization_id
  billing_account     = var.google_workspace_new_project_billing_account_id
  auto_create_network = true
}
resource "google_service_account" "service_account" {
  count        = var.google_workspace_integration_required ? 1 : 0
  display_name = var.google_workspace_service_account_display_name
  account_id   = "${lower(join("-",split(" ",var.google_workspace_service_account_display_name)))}-${random_string.this[0].id}"
  project      = length(var.google_workspace_existing_project_id) > 0 ? var.google_workspace_existing_project_id : google_project.new_project[0].project_id
}
resource "google_service_account_key" "service_account_key" {
  count              = var.google_workspace_integration_required ? 1 : 0
  service_account_id = google_service_account.service_account[0].id
  public_key_type    = "TYPE_X509_PEM_FILE"
}
resource "google_project_service" "workspaces_APIs" {
  for_each = {
    for k, v in local.google_apis : k => v
    if var.google_workspace_integration_required
  }
  service = each.value
  project = length(var.google_workspace_existing_project_id) > 0 ? var.google_workspace_existing_project_id : google_project.new_project[0].project_id
}
