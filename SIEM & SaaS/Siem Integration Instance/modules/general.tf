terraform {
  required_version = ">= 0.13.1"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 4"
    }
  }
}

# Variables
// Application validator
variable "okta_integration_required" {}
variable "google_workspace_integration_required" {}
variable "jumpcloud_integration_required" {}
variable "crowdstrike_integration_required" {}
// Coralogix vars
variable "coralogix_domain" {
  type    = string
  default = "Europe"
  validation {
    condition     = can(regex("^(?:India|Singapore|Europe|US|Europe2)$", var.coralogix_domain))
    error_message = "Invalid Coralogix domain."
  }
}
variable "coralogix_private_key" {
  type = string
  validation {
    condition     = can(regex("^[a-f0-9]{8}\\-(?:[a-f0-9]{4}\\-){3}[a-f0-9]{12}$", var.coralogix_private_key))
    error_message = "The PrivateKey should be valid UUID string."
  }
}
variable "coralogix_company_id" {
  type = string
  validation {
    condition     = can(regex("^\\d{5,7}$", var.coralogix_company_id))
    error_message = "Invalid company ID."
  }
}
// AWS vars
variable "aws_subnet_id" {
  type        = string
  description = "Subnet for the EC2 instance"
  validation {
    condition     = can(regex("^subnet-[0-9a-f]+$", var.aws_subnet_id))
    error_message = "Invalid subnet ID"
  }
}
variable "aws_instance_type" {
  type    = string
  default = ""
}
variable "aws_ssh_key_name" {
  type        = string
  default     = ""
  description = "The key to SSH the integrations instance"
}
variable "aws_public_instance" {
  type        = bool
  default     = true
  description = "Decide if the EC2 instance should pull a public IP address or not"
}
variable "aws_security_group_id" {
  type        = string
  default     = ""
  description = "External security group to use instead of creating a new one"
}
variable "aws_ssh_ip_address" {
  type        = string
  description = "The public IP address for SSH access to the EC2 instance"
  default     = ""
  validation {
    condition     = var.aws_ssh_ip_address == "" ? true : can(regex("^(?:\\d{1,3}\\.){3}\\d{1,3}\\/\\d{1,2}$", var.aws_ssh_ip_address))
    error_message = "IP address is not valid - expected x.x.x.x/x."
  }
}
variable "aws_additional_tags" {
  type    = map(string)
  default = {}
}
variable "aws_instance_disk_type" {
  type = string
  description = "The root disk type used in the EC2 instance"
  default = "gp3"
  validation {
    condition = var.aws_instance_disk_type == "" ? true : can(regex("^(gp[23]|io[12])$", var.aws_instance_disk_type))
    error_message = "Invalid disk type."
  }
}
variable "aws_ebs_encryption" {
  type = bool
  description = "Decide id the root EBS volume of the instance should be encrypted"
  default = true
}

# Data
data "aws_region" "current" {}
data "aws_subnet" "subnet" {
  id = var.aws_subnet_id
}
data "http" "external_ip_address" {
  count = local.load_level > 0 ? 1 : 0
  url   = "http://ifconfig.me"
}

# Locals
locals {
  singles_map = {
    Europe    = "api.coralogix.com"
    Europe2   = "api.eu2.coralogix.com"
    India     = "api.app.coralogix.in"
    US        = "api.coralogix.us"
    Singapore = "api.coralogixsg.com"
  }
  ubuntu-amis-map = {
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
  user_instance_pass = join("", split("-", var.coralogix_private_key))
}
// Load Calculator ------>
locals {
  okta_integration             = var.okta_integration_required ? 1 : 0
  google_workspace_integration = var.google_workspace_integration_required ? 1 : 0
  jumpcloud_integration        = var.jumpcloud_integration_required ? 2 : 0
  crowdstrike_integration      = var.crowdstrike_integration_required ? 1 : 0

  load_level             = local.okta_integration + local.google_workspace_integration + local.jumpcloud_integration + local.crowdstrike_integration
  instance_types_by_load = local.load_level <= 2 ? "t3a.small" : (local.load_level == 3 ? "c5.large" : (local.load_level == 4 ? "c5.xlarge" : "m5.xlarge"))
}
// Docker installation -->
locals {
  docker_install = <<EOF
sudo apt-get remove docker docker-engine docker.io containerd runc
sudo apt-get install ca-certificates curl gnupg lsb-release -y
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
sudo usermod -aG docker ubuntu
sleep 2
newgrp docker
EOF
}

# Resources
resource "aws_instance" "this" {
  count                       = local.load_level > 0 ? 1 : 0
  ami                         = lookup(local.ubuntu-amis-map, data.aws_region.current.id)
  instance_type               = length(var.aws_instance_type) > 0 ? var.aws_instance_type : local.instance_types_by_load
  key_name                    = var.aws_ssh_key_name
  associate_public_ip_address = var.aws_public_instance
  subnet_id                   = var.aws_subnet_id
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }
  root_block_device {
    volume_type = length(var.aws_instance_disk_type) > 0 ? var.aws_instance_disk_type : "gp3"
    encrypted   = var.aws_ebs_encryption
  }
  vpc_security_group_ids = [
    var.aws_security_group_id != "" ? var.aws_security_group_id : aws_security_group.this[0].id
  ]
  tags = merge(var.aws_additional_tags,
    {
      Name         = "Integrations to Coralogix"
      Terraform-execution-ID = random_string.this[0].id
    }
  )
  user_data = <<EOF
#!/bin/bash
echo -e "${local.user_instance_pass}\n${local.user_instance_pass}" | /usr/bin/passwd ubuntu
apt update
${var.okta_integration_required || var.crowdstrike_integration_required || var.google_workspace_integration_required ? local.docker_install : ""}
mkdir /home/ubuntu/integrations
${var.okta_integration_required ? local.okta_user_data : ""}
${var.crowdstrike_integration_required ? local.crowdstrike_user_data : ""}
${var.jumpcloud_integration_required ? local.jumpcloud_user_data : ""}
${var.google_workspace_integration_required ? local.google_workspace_user_data : ""}
EOF
}
resource "aws_security_group" "this" {
  count       = var.aws_security_group_id == "" && local.load_level > 0 ? 1 : 0
  name        = "Security-Group-${random_string.this[0].id}"
  vpc_id      = data.aws_subnet.subnet.vpc_id
  description = "A security group for Snowbit integrations instance"
  tags        = merge(var.aws_additional_tags,
    {
      Terraform-ID = random_string.this[0].id
    }
  )
  ingress {
    description = var.aws_ssh_ip_address == "0.0.0.0/0" ?  "SSH from the world" : length(var.aws_ssh_ip_address) > 0 ? "SSH from user provided IP - ${var.aws_ssh_ip_address}" : "SSH from the creators public IP - ${data.http.external_ip_address[0].response_body}/32"
    cidr_blocks = [
      length(var.aws_ssh_ip_address) > 0 ? var.aws_ssh_ip_address : "${data.http.external_ip_address[0].response_body}/32"
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
resource "random_string" "this" {
  count   = local.load_level > 0 ? 1 : 0
  length  = 6
  special = false
  upper   = false
}
