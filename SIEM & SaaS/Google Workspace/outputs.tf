output "Coralogix" {
  value = {
    Application_Name = var.coralogix_application_name
    Subsystem_Name   = var.coralogix_subsystem_name
    Company_ID       = var.coralogix_company_id
    Domain           = {
      Region               = var.coralogix_domain
      Filebeat_certificate = lookup(var.filebeat_certificate_map_file_name, var.coralogix_domain)
      Filebeat_URL = lookup(var.filebeat_certificates_map_url, var.coralogix_domain)
    }
  }
}
output "GCP" {
  value = {
    Project              = length(var.new_project_name) > 0 ? "Creating a new project called ${var.new_project_name}" : "Used an existing project provided by user named ${data.google_project.existing.name}"
    Service_Account_Name = length(var.new_project_name) > 0 ? "Creating a new service account called ${google_service_account.service_account.id}" : "Used an existing service account provided by user named ${var.service_account_id}"
  }
}
output "AWS" {
  value = {
    Instance = {
      SSH_Key_Name     = var.ssh_key
      Is_public        = var.public_instance == true ? "Yes" : "No"
      EBS_is_encrypted = var.ec2_volume_encryption == true ? "Yes" : "No"
      Security_group   = length(var.security_group_id) > 0 ? "Used user provided security group - ${var.security_group_id}" : "Created new security group - ${aws_security_group.SecurityGroup[0].id}"
    }
    Subnet_ID       = data.aws_subnet.filebeat_subnet.id
    VPC-ID          = data.aws_subnet.filebeat_subnet.vpc_id
    Additional_Tags = var.additional_tags
  }
}