data "google_compute_subnetwork" "this" {
  name = var.project_subnetwork_vpc
}
data "local_sensitive_file" "cred" {
  filename = var.credentials_file
}
