output "Coralogix" {
  sensitive = true
  value = {
    Application_Name = var.coralogix_applicationName
    Domain           = var.coralogix_domain
    Private_Key      = {
      key = var.coralogix_private_key
    }

  }
}
output "Google_Workspace" {
  value = {
    Primary_Admin = var.google_workspace_primary_admin_email_address
  }
}
output "GCP" {
  value = {
    Service_Account_ID = google_service_account.this.unique_id
    Machine = {
      Machine_ID                    = google_compute_instance.this.id
      Service_Account_Email         = google_compute_instance.this.service_account[0].email
      Public_Network_Configurations = google_compute_instance.this.network_interface[0].access_config
      Machine_Type                  = var.gcp_machine_type
      Disk_Type                     = var.gcp_boot_disk_type
      Security                      = {
        Secure_boot            = var.gcp_instance_enable_secure_boot
        Integrity_Monitoring   = var.gcp_instance_enable_integrity_monitoring
        VTPM                   = var.gcp_instance_enable_vtpm
        using_project_SSH_keys = var.gcp_block_project_ssh_keys
      }
    }
  }
}