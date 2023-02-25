# AWS Variables --->
variable "existing_project_id" {
  type        = string
  description = "GCP project name"
}
variable "service_account_id" {
  type        = string
  description = "The service account ID of choise"
  validation {
    condition     = can(regex("[a-z]([-a-z0-9]*[a-z0-9])", var.service_account_id))
    error_message = "Invalid account ID - must be 6-30 characters long"
  }
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
# AWS Data --->
data "google_project" "existing" {
  project_id = var.existing_project_id
}

# AWS Resources --->
resource "google_project" "new_project" {
  count           = length(var.new_project_name) > 0 ? 1 : 0
  name            = var.new_project_name
  project_id      = "${lower(join("-",split(" ",var.new_project_name)))}-${random_string.id.id}"
  org_id          = var.new_project_organization
  billing_account = var.new_project_billing_account
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
resource "google_project_service" "Admin_SDK" {
  service = "admin.googleapis.com"
  project = var.existing_project_id
}
resource "google_project_service" "Contacts_API" {
  service = "contacts.googleapis.com"
  project = var.existing_project_id
}
resource "google_project_service" "Google_Workspace_Migrate_API" {
  service = "migrate.googleapis.com"
  project = var.existing_project_id
}
resource "google_project_service" "Gmail_API" {
  service = "gmail.googleapis.com"
  project = var.existing_project_id
}
resource "google_project_service" "Google_Calendar_API" {
  service = "calendar-json.googleapis.com"
  project = var.existing_project_id
}
resource "google_project_service" "Google_Drive_API" {
  service = "drive.googleapis.com"
  project = var.existing_project_id
}
resource "google_project_service" "Groups_Migration_API" {
  service = "groupsmigration.googleapis.com"
  project = var.existing_project_id
}
resource "google_project_service" "Groups_Settings_API" {
  service = "groupssettings.googleapis.com"
  project = var.existing_project_id
}
resource "google_project_service" "Google_Sheets_API" {
  service = "sheets.googleapis.com"
  project = var.existing_project_id
}
resource "google_project_service" "Tasks_API" {
  service = "tasks.googleapis.com"
  project = var.existing_project_id
}
