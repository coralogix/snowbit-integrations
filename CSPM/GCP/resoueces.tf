resource "google_compute_instance" "cspm-instance-public" {
  machine_type = var.machine_type
  name         = "snowbit-cspm"
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
      type  = var.boot_disk_type
    }
  }
  service_account {
    email  = var.service_account
    scopes = ["cloud-platform"]
  }
  metadata_startup_script = "#!/bin/bash\nsudo apt update\nsudo apt-get remove docker docker-engine docker.io containerd runc\nsudo apt-get install ca-certificates curl gnupg lsb-release -y\nsudo mkdir -p /etc/apt/keyrings\ncurl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg\necho \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null\nsudo chmod a+r /etc/apt/keyrings/docker.gpg\nsudo apt-get update\nsudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y\nsudo usermod -aG docker ubuntu\necho '${data.local_sensitive_file.cred.content}' > /home/ubuntu/credentials.json\nnewgrp docker\ncrontab -l | { cat; echo \"${var.cronjob} docker rm snowbit-cspm ; docker rmi coralogixrepo/snowbit-cspm:${var.CSPMVersion} ; docker run --name snowbit-cspm -d -e PYTHONUNBUFFERED=1 -e CLOUD_PROVIDER=gcp -e CORALOGIX_ENDPOINT_HOST=${lookup(var.grpc-endpoints-map, var.GRPC_Endpoint)} -e APPLICATION_NAME=${var.applicationName} -e SUBSYSTEM_NAME=${var.subsystemName} -e TESTER_LIST=${var.TesterList} -e API_KEY=${var.PrivateKey} -e REGION_LIST=${var.RegionList} -e CORALOGIX_ALERT_API_KEY=${var.alertAPIkey} -e COMPANY_ID=${var.Company_ID} -e GOOGLE_APPLICATION_CREDENTIALS=/home/ubuntu/credentials.json -v /home/ubuntu:/home/ubuntu/ coralogixrepo/snowbit-cspm:${var.CSPMVersion}\"; } | crontab -\nsudo docker pull coralogixrepo/snowbit-cspm:${var.CSPMVersion}"
  network_interface {
    network    = data.google_compute_subnetwork.this.network
    subnetwork = var.project_subnetwork_vpc
    access_config {}
  }
}
resource "google_service_account" "cspm-service-account" {
  account_id = "cspm-service-account-${random_string.id.id}"
}
resource "google_project_iam_custom_role" "cspm-role" {
  permissions = []
  role_id     = "cspm-role-${random_string.id.id}"
  title       = "cspm-role"
}
resource "random_string" "id" {
  length  = 6
  upper   = false
  special = false
}