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
variable "coralogix_domain" {
  type    = string
  default = "Europe"
  validation {
    condition     = can(regex("^(?:India|Singapore|Europe|US)$", var.coralogix_domain))
    error_message = "Invalid Coralogix domain"
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
  type        = string
  description = "The public IP address for SSH access to the EC2 instance"
  validation {
    condition     = var.SSHIpAddress == "" ? true : can(regex("^(?:\\d{1,3}\\.){3}\\d{1,3}\\/\\d{1,2}$", var.SSHIpAddress))
    error_message = "IP address is not valid - expected x.x.x.x/x"
  }
}
variable "additional_tags" {
  type    = map(string)
  default = {}
}
variable "public_instance" {
  type = bool
  default = true
}
variable "client_secret" {
  type = string
  sensitive = true
}
variable "client_id" {
  type = string
  sensitive = true
}
variable "api_url" {
  type = string
  default = "api.crowdstrike.com"
}

# Data --->
data "aws_region" "current" {}
data "aws_subnet" "subnet" {
  id = var.Subnet_ID
}
data "http" "external-ip-address" {
  url = "http://ifconfig.me"
}

# Locals --->
locals {
  coralogix_endpoint = {
    Europe    = "api.coralogix.com"
    Europe2   = "api.eu2.coralogix.com"
    India     = "api.app.coralogix.in"
    US        = "api.coralogix.us"
    Singapore = "api.coralogixsg.com"
  }
  fluent_bit_conf_file = <<EOF
[SERVICE]
    flush        1
    log_level    info
    parsers_file parsers.conf
[INPUT]
    name                 tail
    path                 /var/log/crowdstrike/falconhoseclient/output
    multiline.parser     multiline_parser
[FILTER]
    Name              parser
    Match             *
    Key_Name          log
    Parser            json_parser
[FILTER]
    Name        nest
    Match       *
    Operation   nest
    Wildcard    *
    Nest_under  text
[FILTER]
    Name    modify
    Match   *
    Add    applicationName ${var.coralogix_application_name}
    Add    subsystemName ${var.coralogix_subsystem_name}
    Add    computerName CrowdStrike
[OUTPUT]
    Name                  http
    Match                 *
    Host                  ${lookup(local.coralogix_endpoint, var.coralogix_domain)}
    Port                  443
    URI                   /logs/rest/singles
    Format                json_lines
    TLS                   On
    Header                private_key ${var.coralogix_private_key}
    compress              gzip
    Retry_Limit           10
EOF
  parser_file          = <<EOF
[MULTILINE_PARSER]
    name          multiline_parser
    type          regex
    flush_timeout 1000
    #
    # Regex rules for multiline parsing
    # ---------------------------------
    #
    # configuration hints:
    #
    #  - first state always has the name: start_state
    #  - every field in the rule must be inside double quotes
    #
    # rules |   state name  | regex pattern                  | next state
    # ------|---------------|--------------------------------------------
    rule      "start_state"   "/^{/"                        "cont"
    rule      "cont"          "/^[^{]/"                     "cont"
[PARSER]
    name json_parser
    format json
EOF
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
curl https://raw.githubusercontent.com/fluent/fluent-bit/master/install.sh | sh
wget https://snowbit-shared-resources.s3.eu-west-1.amazonaws.com/crowdstrike-cs-falconhoseclient_2.12.0_amd64.deb
sudo dpkg -i crowdstrike-cs-falconhoseclient_2.12.0_amd64.deb
echo '${local.fluent_bit_conf_file}' > /etc/fluent-bit/fluent-bit.conf
echo '${local.parser_file}' > /etc/fluent-bit/parsers.conf
systemctl start fluent-bit
sed -i '3s/.*/api_url = https:\/\/${var.api_url}\/sensors\/entities\/datafeed\/v2/' /opt/crowdstrike/etc/cs.falconhoseclient.cfg
sed -i '4s/.*/request_token_url = https:\/\/${var.api_url}\/oauth2\/token/' /opt/crowdstrike/etc/cs.falconhoseclient.cfg
sed -i '11s/.*/client_id = ${var.client_id}/' /opt/crowdstrike/etc/cs.falconhoseclient.cfg
sed -i '13s/.*/client_secret = ${var.client_secret}/' /opt/crowdstrike/etc/cs.falconhoseclient.cfg
EOF
  tags      = merge(var.additional_tags,
    {
      Name         = "CrowdStrike to Coralogix"
      Terraform-ID = random_string.id.id
    }
  )
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