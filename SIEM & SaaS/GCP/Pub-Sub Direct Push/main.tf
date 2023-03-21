terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4"
    }
  }
}

variable "project_id" {
  type = string
}
variable "private_key" {
  type = string
  validation {
    condition     = can(regex("^[a-f0-9]{8}\\-(?:[a-f0-9]{4}\\-){3}[a-f0-9]{12}$", var.private_key))
    error_message = "The PrivateKey should be valid UUID string."
  }
}
variable "application_name" {
  type = string
}
variable "subsystem_name" {
  type = string
}
variable "cx_region_map" {
  type    = map(string)
  default = {
    Europe    = "coralogix.com"
    Europe2   = "eu2.coralogix.com"
    India     = "app.coralogix.in"
    Singapore = "coralogixsg.com"
    US        = "app.coralogix.us"
  }
}
variable "cx_region" {
  type = string
  validation {
    condition     = can(regex("^Europe|Europe2|India|Singapore|US$", var.cx_region))
    error_message = "Invalid Coralogix region."
  }
}
variable "topic_name" {
  type = string
}
variable "sink_name" {
  type = string
}
variable "organization_id" {
  type = string
  validation {
    condition = can(regex("^\\d{12}$", var.organization_id))
    error_message = "Invalid Organization ID."
  }
}

resource "google_pubsub_topic" "this" {
  name    = var.topic_name
  project = var.project_id
}
resource "google_pubsub_topic_iam_binding" "this" {
  members = ["allUsers"]
  role    = "roles/writer"
  topic   = google_pubsub_topic.this.name
  project = var.project_id
}
resource "google_logging_organization_sink" "this" {
  name             = var.sink_name
  org_id           = var.organization_id
  include_children = true
  destination      = "pubsub.googleapis.com/${google_pubsub_topic.this.id}"
}
resource "google_pubsub_subscription" "this" {
  depends_on                 = [google_pubsub_topic.this, google_logging_organization_sink.this]
  name                       = var.topic_name
  topic                      = google_pubsub_topic.this.id
  project                    = var.project_id
  message_retention_duration = "604800s"
  ack_deadline_seconds       = "10"
  push_config {
    push_endpoint = "https://gcp-ingress.${lookup(var.cx_region_map, var.cx_region)}/api/v1/gcp/logs?key=${var.private_key}&application=${var.application_name}&subsystem=${var.subsystem_name}"
  }
  expiration_policy {
    ttl = "2678400s"
  }
  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }
}
