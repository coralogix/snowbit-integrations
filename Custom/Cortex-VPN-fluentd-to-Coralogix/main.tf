terraform {
  required_providers {
    aws = {
      version = "~> 4"
    }
  }
}

// Coralogix
variable "coralogix_application_name" {
  type = string
}
variable "coralogix_subsystem_name" {
  type = string
}
variable "coralogix_private_key" {
  description = "The 'send your data' API key from Coralogix account"
  sensitive   = true
  validation {
    condition     = can(regex("^\\w{8}-(\\w{4}-){3}\\w{12}$", var.coralogix_private_key))
    error_message = "The PrivateKey should be valid UUID string."
  }
}
variable "coralogix_domain" {
  type = string
  validation {
    condition     = can(regex("^Europe|Europe2|India|Singapore|US$", var.coralogix_domain))
    error_message = "Invalid Coralogix domain."
  }
}

// AWS
variable "aws_ssh_key_name" {
  type    = string
  default = ""
}
variable "aws_instance_type" {
  type    = string
  default = "t3a.small"
}
variable "aws_security_group_id" {
  type    = string
  default = ""
  validation {
    condition     = var.aws_security_group_id == "" ? true : can(regex("^sg\\-[a-f0-9]+", var.aws_security_group_id))
    error_message = "Invalid security group ID."
  }
}
variable "aws_subnet_id" {
  type = string
  validation {
    condition     = can(regex("^subnet\\-[a-f0-9]+", var.aws_subnet_id))
    error_message = "Invalid subnet ID."
  }
}
variable "aws_ssh_ip_address" {
  type        = string
  description = "The IP address that will have access to the instance - defaults to your external IP address"
  default     = ""
}
variable "aws_public_instance" {
  type    = bool
  default = true
}
variable "aws_ec2_volume_encryption" {
  type    = bool
  default = true
}
variable "aws_additional_tags" {
  type    = map(string)
  default = {}
}

// Cortex VPN
variable "cortex_sending_port" {
  type    = number
  default = 6144
  validation {
    condition     = var.cortex_sending_port >= 1024 && var.cortex_sending_port <= 65535
    error_message = "Invalid port selected."
  }
}
variable "cortex_sending_ip" {
  type    = string
  default = "0.0.0.0"
}

// Fluent-D
variable "fluentd_input_type" {
  type    = string
  default = "udp"
  validation {
    condition     = can(regex("^udp|tcp|http$", var.fluentd_input_type))
    error_message = "Invalid shipper method type."
  }
}

locals {
  coralogix_domain = {
    Europe    = "coralogix.com"
    Europe2   = "eu2.coralogix.com"
    India     = "app.coralogix.in"
    Singapore = "coralogixsg.com"
    US        = "coralogix.us"
  }
  fluentd = {
    input = {
      udp  = <<EOF
<source>
    @type udp
    @label @CORALOGIX
    port ${var.cortex_sending_port}
    bind ${length(var.cortex_sending_ip) > 0 ? var.cortex_sending_ip : "0.0.0.0"}
    body_size_limit 32m
    tag cx.udp
    <parse>
        @type none
    </parse>
</source>
EOF
      tcp  = <<EOF
<source>
    @type tcp
    @label @CORALOGIX
    port ${var.cortex_sending_port}
    bind ${length(var.cortex_sending_ip) > 0 ? var.cortex_sending_ip : "0.0.0.0"}
    body_size_limit 32m
    tag cx.tcp
    <parse>
        @type none
    </parse>
</source>
EOF
      http = <<EOF
<source>
    @type http
    @label @CORALOGIX
    port ${var.cortex_sending_port}
    bind ${length(var.cortex_sending_ip) > 0 ? var.cortex_sending_ip : "0.0.0.0"}
    body_size_limit 32m
    keepalive_timeout 10s
</source>
EOF
    }
    output = <<EOF
<label @CORALOGIX>
    <filter **>
        @type record_transformer
        @log_level warn
        enable_ruby true
        auto_typecast true
        renew_record true
        <record>
            applicationName "${var.coralogix_application_name}"
            subsystemName "${var.coralogix_subsystem_name}"
            text ${base64decode("JHtyZWNvcmRbIm1lc3NhZ2UiXX0=")}
        </record>
    </filter>

    <match **>
        @type http
        @id http_to_coralogix
        endpoint "https://api.${lookup(local.coralogix_domain, var.coralogix_domain)}/logs/rest/singles"
        headers {"private_key": "${var.coralogix_private_key}"}
        retryable_response_codes 503
        error_response_as_unrecoverable false
        <buffer>
            @type memory
            chunk_limit_size 10MB
            compress gzip
            flush_interval 1s
            retry_max_times 5
            retry_type periodic
            retry_wait 2
        </buffer>
    </match>
</label>
EOF
  }
}

data "aws_ami" "this" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/*/ubuntu*2*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}
data "aws_subnet" "this" {
  id = var.aws_subnet_id
}
data "http" "external-ip-address" {
  url = "http://ifconfig.me"
}

resource "aws_instance" "this" {
  ami                         = data.aws_ami.this.image_id
  instance_type               = var.aws_instance_type
  key_name                    = var.aws_ssh_key_name
  associate_public_ip_address = var.aws_public_instance
  subnet_id                   = data.aws_subnet.this.id
  security_groups             = [
    length(var.aws_security_group_id) > 0 ? var.aws_security_group_id : aws_security_group.this[0].id
  ]
  tags = merge(var.aws_additional_tags, {
    Terraform-ID    = random_string.this.id
    Name            = "Cortex VPN shipper to Coralogix"
    Shipping-Method = "Fluent-D"
  })
  root_block_device {
    encrypted   = var.aws_ec2_volume_encryption
    volume_type = "gp3"
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }
  user_data = <<EOF
#!/bin/bash

curl -fsSL https://toolbelt.treasuredata.com/sh/install-${split("/", data.aws_ami.this.name)[0]}-${split("-", data.aws_ami.this.name)[2]}-td-agent4.sh | sh
echo '${lookup(local.fluentd.input, var.fluentd_input_type)}' > /etc/td-agent/td-agent.conf
echo '${local.fluentd.output}' >> /etc/td-agent/td-agent.conf
systemctl restart td-agent.service
EOF
}
resource "aws_eip" "this" {
  instance = aws_instance.this.id
}
resource "aws_security_group" "this" {
  name        = "Security-Group-${random_string.this.id}"
  count       = length(var.aws_security_group_id) > 0 ? 0 : 1
  vpc_id      = data.aws_subnet.this.vpc_id
  description = "A security group for Snowbit Integration"
  tags        = merge(var.aws_additional_tags, {
    Terraform-ID = random_string.this.id
  })
  ingress {
    description = var.aws_ssh_ip_address == "0.0.0.0/0" ?  "SSH from the world" : length(var.aws_ssh_ip_address) > 0 ? "SSH from user provided IP - ${var.aws_ssh_ip_address}" : "SSH from the creators public IP - ${data.http.external-ip-address.response_body}/32"
    cidr_blocks = [
      length(var.aws_ssh_ip_address) > 0 ? var.aws_ssh_ip_address : "${data.http.external-ip-address.response_body}/32"
    ]
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    security_groups  = []
    self             = false
  }
  ingress {
    description = length(var.cortex_sending_ip) > 0 ? "Allow access to Cortex IP only on port ${var.cortex_sending_port}" : "Allow any access on port ${var.cortex_sending_port}"
    cidr_blocks = [length(var.cortex_sending_ip) > 0 ? "${var.cortex_sending_ip}/32" : "0.0.0.0/0"]
    from_port   = var.cortex_sending_port
    protocol    = var.fluentd_input_type
    to_port     = var.cortex_sending_port
  }
  egress {
    description = "Allow outbound traffic to anywhere"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "random_string" "this" {
  length  = 6
  upper   = false
  special = false
}
