# AWS Variables --->
variable "ssh_key" {
  type = string
}
variable "subnet_id" {
  type = string
  validation {
    condition     = can(regex("^subnet\\-[a-f0-9]+", var.subnet_id))
    error_message = "Invalid subnet ID"
  }
}
variable "public_instance" {
  type = bool
}
variable "security_group_id" {
  type = string
  validation {
    condition     = var.security_group_id == "" ? true : can(regex("^sg\\-[a-f0-9]+", var.security_group_id))
    error_message = "Invalid security group ID"
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
variable "filebeat_certificates_map_url" {
  type    = map(string)
  default = {
    Europe = "https://coralogix-public.s3-eu-west-1.amazonaws.com/certificate/"
    India  = "https://coralogix-public.s3-eu-west-1.amazonaws.com/certificate/"
    US     = "https://www.amazontrust.com/repository/AmazonRootCA1.pem"
  }
}
variable "filebeat_certificate_map_file_name" {
  type    = map(string)
  default = {
    Europe = "Coralogix-EU.crt"
    India  = "Coralogix-IN.pem"
    US     = "AmazonRootCA1.pem"
  }
}
variable "logstash_map" {
  type    = map(string)
  default = {
    Europe = "logstashserver.coralogix.com"
    India  = "logstash.app.coralogix.in"
    US     = "logstashserver.coralogix.us"
  }
}
variable "coralogix_domain" {
  type    = string
  default = "Europe"
}
variable "primary_google_workspace_admin_email" {
  type = string
}
variable "coralogix_private_key" {
  type = string
}
variable "coralogix_application_name" {
  type = string
}
variable "coralogix_subsystem_name" {
  type = string
}
variable "coralogix_company_id" {
  type = string
}
# AWS Data --->
data "aws_subnet" "filebeat_subnet" {
  id = var.subnet_id
}
data "http" "external-ip-address" {
  url = "http://ifconfig.me"
}
# AWS Resources --->
resource "aws_instance" "filebeat_instance" {
  ami                         = "ami-06d94a781b544c133"
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
    var.delegated_account: "${var.primary_google_workspace_admin_email}"
  user_accounts:
    enabled: true
    var.jwt_file: "/etc/filebeat/google_credential_file.json"
    var.delegated_account: "${var.primary_google_workspace_admin_email}"
  login:
    enable: true
    var.jwt_file: "/etc/filebeat/google_credential_file.json"
    var.delegated_account: "${var.primary_google_workspace_admin_email}"
  admin:
    enabled: true
    var.jwt_file: "/etc/filebeat/google_credential_file.json"
    var.delegated_account: "${var.primary_google_workspace_admin_email}"
  drive:
    enabled: true
    var.jwt_file: "/etc/filebeat/google_credential_file.json"
    var.delegated_account: "${var.primary_google_workspace_admin_email}"
  groups:
    enabled: true
    var.jwt_file: "/etc/filebeat/google_credential_file.json"
    var.delegated_account: "${var.primary_google_workspace_admin_email}"

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
  count       = length(var.security_group_id) > 0 ? 0 : 1
  vpc_id      = data.aws_subnet.filebeat_subnet.vpc_id
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
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}
resource "random_string" "id" {
  length  = 6
  upper   = false
  special = false
}