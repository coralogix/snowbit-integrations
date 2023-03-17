terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4"
    }
  }
}
# Variables --->
variable "coralogix_private_key" {
  type = string
  validation {
    condition     = can(regex("^[a-f0-9]{8}\\-(?:[a-f0-9]{4}\\-){3}[a-f0-9]{12}$", var.coralogix_private_key))
    error_message = "The PrivateKey should be valid UUID string"
  }
}
variable "coralogix_application_name" {
  type = string
}
variable "coralogix_subsystem_name" {
  type = string
}
variable "coralogix_company_id" {
  type = string
  validation {
    condition     = can(regex("^\\d{5,7}$", var.coralogix_company_id))
    error_message = "Invalid company ID"
  }
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
variable "instanceType" {
  type = string
}
variable "SSHKeyName" {
  type        = string
  default     = ""
  description = "The key to SSH the CSPM instance"
}
variable "public_instance" {
  type        = bool
  default     = true
  description = "Decide if the EC2 instance should pull a public IP address or not"
}
variable "Subnet_ID" {
  type        = string
  description = "Subnet for the EC2 instance"
  validation {
    condition     = can(regex("^subnet-[0-9a-f]+$", var.Subnet_ID))
    error_message = "Invalid subnet ID"
  }
}
variable "security_group_id" {
  type        = string
  default     = ""
  description = "External security group to use instead of creating a new one"
}
variable "SSHIpAddress" {
  type = string
  description = "The public IP address for SSH access to the EC2 instance"
  validation {
    condition = var.SSHIpAddress == "" ? true : can(regex("^(?:\\d{1,3}\\.){3}\\d{1,3}\\/\\d{1,2}$", var.SSHIpAddress))
    error_message = "IP address is not valid - expected x.x.x.x/x"
  }
}
variable "additional_tags" {
  type    = map(string)
  default = {}
}
variable "okta_api_key" {
  type = string
}
variable "okta_domain" {
  type = string
  description = "for example - 'https://yourOktaDomain/api/v1/logs'"
}
variable "filebeat_certificates_map_url" {
  type    = map(string)
  default = {
    Europe    = "https://coralogix-public.s3-eu-west-1.amazonaws.com/certificate/"
    India     = "https://coralogix-public.s3-eu-west-1.amazonaws.com/certificate/"
    US        = "https://www.amazontrust.com/repository/AmazonRootCA1.pem"
    Singapore = "https://www.amazontrust.com/repository/AmazonRootCA1.pem"
  }
}
variable "filebeat_certificate_map_file_name" {
  type    = map(string)
  default = {
    Europe    = "Coralogix-EU.crt"
    India     = "Coralogix-IN.pem"
    US        = "AmazonRootCA1.pem"
    Singapore = "AmazonRootCA1.pem"
  }
}
variable "coralogix_domain" {
  type    = string
  default = "Europe"
  validation {
    condition     = can(regex("^(?:India|Singapore|Europe|US)$", var.coralogix_domain))
    error_message = "Invalid Coralogix domain"
  }
}
variable "logstash_map" {
  type    = map(string)
  default = {
    Europe    = "logstashserver.coralogix.com"
    India     = "logstash.app.coralogix.in"
    US        = "logstashserver.coralogix.us"
    Singapore = "logstashserver.coralogixsg.com"
  }
}

# Data --->
data "aws_region" "current" {}
data "aws_subnet" "subnet" {
  id = var.Subnet_ID
}
data "http" "external-ip-address" {
  url = "http://ifconfig.me"
}

# Resources --->
resource "aws_instance" "this" {
  ami                         = lookup(var.ubuntu-amis-map, data.aws_region.current.name)
  instance_type               = length(var.instanceType) > 0 ? var.instanceType : "t3a.small"
  key_name                    = var.SSHKeyName
  associate_public_ip_address = var.public_instance
  subnet_id                   = var.Subnet_ID
  vpc_security_group_ids      = [
    var.security_group_id != "" ? var.security_group_id : aws_security_group.SecurityGroup[0].id
  ]
  user_data = <<EOF
#!/bin/bash
apt update
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.6.2-amd64.deb
sudo dpkg -i filebeat-8.6.2-amd64.deb
rm filebeat-8.6.2-amd64.deb
mkdir /etc/filebeat/certs
cd /etc/filebeat/certs
wget ${lookup(var.filebeat_certificates_map_url, var.coralogix_domain)}${lookup(var.filebeat_certificate_map_file_name, var.coralogix_domain)}
cd /etc/filebeat

echo 'ignore_older: 3h
filebeat.modules:
- module: okta
  system:
    var.url: ${var.okta_domain}
    var.api_key: '${var.okta_api_key}'

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
EOF
}
resource "aws_security_group" "SecurityGroup" {
  count       = var.security_group_id == "" ? 1 : 0
  name        = "CSPM-Security-Group-${random_string.id.id}"
  vpc_id      = data.aws_subnet.subnet.vpc_id
  description = "A security group for Snowbit CSPM"
  tags        = merge(var.additional_tags,
    {
      Terraform-ID = random_string.id.id
    }
  )
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
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
resource "random_string" "id" {
  length  = 6
  special = false
  upper   = false
}