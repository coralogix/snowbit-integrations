# AWS Variables --->
variable "ssh_key" {
  type = string
  default = ""
}
variable "subnet_id" {
  type = string
  validation {
    condition     = var.subnet_id == "" ? true : can(regex("^subnet\\-[a-f0-9]+", var.subnet_id))
    error_message = "Invalid subnet ID."
  }
}
variable "public_instance" {
  type = bool
}
variable "security_group_id" {
  type = string
  validation {
    condition     = var.security_group_id == "" ? true : can(regex("^sg\\-[a-f0-9]+", var.security_group_id))
    error_message = "Invalid security group ID."
  }
}
variable "additional_tags" {
  type    = map(string)
  default = {}
}
variable "ec2_volume_encryption" {
  type = bool
}
variable "SSHIpAddress" {
  type = string
}
variable "ubuntu-amis-map" {
  type    = map(string)
  default = {
    "us-east-1"      = "ami-08c40ec9ead489470",
    "us-east-2"      = "ami-097a2df4ac947655f",
    "us-west-1"      = "ami-02ea247e531eb3ce6",
    "us-west-2"      = "ami-017fecd1353bcc96e",
    "ap-south-1"     = "ami-062df10d14676e201",
    "ap-northeast-1" = "ami-09a5c873bc79530d9",
    "ap-northeast-2" = "ami-0e9bfdb247cc8de84",
    "ap-northeast-3" = "ami-08c2ee02329b72f26",
    "ap-southeast-1" = "ami-07651f0c4c315a529",
    "ap-southeast-2" = "ami-09a5c873bc79530d9",
    "ca-central-1"   = "ami-0a7154091c5c6623e",
    "eu-central-1"   = "ami-0caef02b518350c8b",
    "eu-west-1"      = "ami-096800910c1b781ba",
    "eu-west-2"      = "ami-0f540e9f488cfa27d",
    "eu-west-3"      = "ami-0493936afbe820b28",
    "eu-north-1"     = "ami-0efda064d1b5e46a5",
    "sa-east-1"      = "ami-04b3c23ec8efcc2d6"
  }
}
# AWS Data --->
data "aws_region" "current" {}
data "aws_subnet" "filebeat_subnet" {
  count = var.subnet_id == "" ? 0 : 1
  id = var.subnet_id
}
data "http" "external-ip-address" {
  url = "http://ifconfig.me"
}
# AWS Resources --->
resource "aws_instance" "filebeat_instance" {
  count = var.instance_cloud_provider == "AWS" ? 1 : 0
  ami                         = lookup(var.ubuntu-amis-map, data.aws_region.current.name)
  key_name                    = var.ssh_key
  instance_type               = "t3a.small"
  associate_public_ip_address = var.public_instance
  subnet_id                   = var.subnet_id
  security_groups             = [
    length(var.security_group_id) > 0 ? var.security_group_id : aws_security_group.SecurityGroup[0].id
  ]
  tags = merge(var.additional_tags, {
    Terraform-ID = random_string.id.id
    Name         = "Google Workspace Integration"
  })
  root_block_device {
    encrypted   = var.ec2_volume_encryption
    volume_type = "gp3"
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }
  user_data = <<EOT
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
resource "aws_security_group" "SecurityGroup" {
  name        = "Security-Group-${random_string.id.id}"
  count       = length(var.security_group_id) > 0 ? 0 : var.instance_cloud_provider == "AWS" ? 1 : 0
  vpc_id      = data.aws_subnet.filebeat_subnet[0].vpc_id
  description = "A security group for Snowbit Integration"
  tags        = merge(var.additional_tags, {
    Terraform-ID = random_string.id.id
  })
  ingress {
    description = var.SSHIpAddress == "0.0.0.0/0" ?  "SSH from the world" : length(var.SSHIpAddress) > 0 ? "SSH from user provided IP - ${var.SSHIpAddress}" : "SSH from the creators public IP - ${data.http.external-ip-address.response_body}/32"
    cidr_blocks = [
      length(var.SSHIpAddress) > 0 ? var.SSHIpAddress : "${data.http.external-ip-address.response_body}/32"
    ]
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    security_groups  = []
    self             = false
  }
  egress {
    description = "Allow outbound traffic to anywhere"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
