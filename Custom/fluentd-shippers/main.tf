variable "coralogix_private_key" {
  type      = string
  sensitive = true
  validation {
    condition     = can(regex("^\\w{8}-(\\w{4}-){3}\\w{12}$", var.coralogix_private_key))
    error_message = "The Coralogix Private Key should be valid UUID string."
  }
}
variable "coralogix_domain" {
  type = string
  validation {
    condition     = can(regex("^Europe|Europe2|India|Singapore|US$", var.coralogix_domain))
    error_message = "Invalid Coralogix endpoint."
  }
}
variable "request" {
  type = map(object({
    type              = string
    app_name          = string
    sub_name          = string
    format            = string
    log_file_path     = optional(string)
    port_to_listen    = optional(string)
    sender_ip_address = optional(string)
  }))
  validation {
    condition = alltrue([
      for types in var.request : contains(["http", "tcp", "udp", "file"], types.type)
    ])
    error_message = "Type key must be either 'http', 'tcp', udp, or 'file'."
  }
}
variable "security_group_id" {
  type    = string
  default = ""
  validation {
    condition     = var.security_group_id == "" ? true : can(regex("^sg\\-[a-f0-9]+", var.security_group_id))
    error_message = "Invalid security group ID."
  }
}
variable "subnet_id" {
  type = string
  validation {
    condition     = can(regex("^subnet\\-[a-f0-9]+", var.subnet_id))
    error_message = "Invalid subnet ID."
  }
}
variable "additional_tags" {
  type    = map(string)
  default = {}
}
variable "SSHIpAddress" {
  type    = string
  default = ""
}
variable "instance_type" {
  type    = string
  default = ""
}
variable "ssh_key" {
  type    = string
  default = ""
}
variable "ec2_volume_encryption" {
  type    = bool
  default = true
}
variable "public_instance" {
  type    = bool
  default = true
}

data "http" "external-ip-address" {
  url = "http://ifconfig.me"
}
data "aws_subnet" "filebeat_subnet" {
  count = var.subnet_id == "" ? 0 : 1
  id    = var.subnet_id
}
data "aws_region" "current" {}

locals {
  docker_install    = <<EOF
sudo apt-get remove docker docker-engine docker.io containerd runc
sudo apt-get update
sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release -y
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker
EOF
  coralogix_domains = {
    Europe    = "coralogix.com"
    Europe2   = "eu2.coralogix.com"
    India     = "app.coralogix.in"
    Singapore = "coralogixsg.com"
    US        = "coralogix.us"
  }
  ubuntu_ami_map = {
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

resource "aws_instance" "this" {
  ami                         = lookup(local.ubuntu_ami_map, data.aws_region.current.name)
  instance_type               = length(var.instance_type) > 0 ? var.instance_type : "t3a.small"
  key_name                    = var.ssh_key
  user_data_replace_on_change = true
  associate_public_ip_address = var.public_instance
  subnet_id                   = var.subnet_id
  security_groups             = [
    length(var.security_group_id) > 0 ? var.security_group_id : aws_security_group.SecurityGroup[0].id
  ]
  user_data = <<EOF
#!/bin/bash
${local.docker_install}
echo '${jsonencode(var.request)}' > /home/ubuntu/shipper_details.json
wget -O /home/ubuntu/script.py https://raw.githubusercontent.com/coralogix/snowbit-integrations/master/Custom/fluentd-shippers/main.py
python3 /home/ubuntu/script.py --api_key ${var.coralogix_private_key} --domain ${lookup(local.coralogix_domains, var.coralogix_domain)}
EOF
  tags      = merge(var.additional_tags, {
    Terraform-ID = random_string.id.id
    Name         = "FluentD shipper(s) to Coralogix"
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
}
resource "aws_security_group" "SecurityGroup" {
  count       = length(var.security_group_id) > 0 ? 0 : 1
  name        = "Security-Group-${random_string.id.id}"
  description = "A security group for Snowbit Integration"
  vpc_id      = data.aws_subnet.filebeat_subnet[0].vpc_id
  tags        = merge(var.additional_tags, {
    Terraform-ID = random_string.id.id
  })
  dynamic "ingress" {
    for_each = var.request.port_to_listen
    content {
      cidr_blocks = [var.request.sender_ip_address]
      from_port   = var.request.port_to_listen
      to_port     = var.request.port_to_listen
      protocol    = var.request.type == "tcp" || var.request.type == "udp" ? var.request.type : "-1"
      self        = false
    }
  }
  ingress {
    description = var.SSHIpAddress == "0.0.0.0/0" ?  "SSH from the world" : length(var.SSHIpAddress) > 0 ? "SSH from user provided IP - ${var.SSHIpAddress}" : "SSH from the creators public IP - ${data.http.external-ip-address.response_body}/32"
    cidr_blocks = [length(var.SSHIpAddress) > 0 ? var.SSHIpAddress : "${data.http.external-ip-address.response_body}/32"]
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
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
resource "random_string" "id" {
  length  = 6
  upper   = false
  special = false
}
