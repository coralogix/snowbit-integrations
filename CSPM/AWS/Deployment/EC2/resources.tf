resource "aws_instance" "cspm-instance" {
  ami                         = data.aws_ami.ubuntu.image_id
  instance_type               = length(var.AWS-instanceType) > 0 ? var.AWS-instanceType : "t3.small"
  key_name                    = var.AWS-SSHKeyName
  iam_instance_profile        = aws_iam_instance_profile.CSPMInstanceProfile.id
  associate_public_ip_address = var.AWS-public_instance
  subnet_id                   = var.AWS-Subnet_ID
  vpc_security_group_ids      = [
    var.AWS-security_group_id != "" ? var.AWS-security_group_id : aws_security_group.CSPMSecurityGroup[0].id
  ]
  user_data = <<EOT
#!/bin/bash
echo -e "${local.user-pass}\n${local.user-pass}" | /usr/bin/passwd ubuntu
${local.docker_install}
${local.docker_command_in_cron}
EOT
  root_block_device {
    volume_type = length(var.AWS-DiskType) > 0 ? var.AWS-DiskType : "gp3"
    encrypted   = var.AWS-ebs_encryption
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }
  tags = merge(var.AWS-additional_tags,
    {
      Name         = "Snowbit CSPM"
      Terraform-ID = random_string.id.id
    },
  )
}
resource "aws_security_group" "CSPMSecurityGroup" {
  name        = "CSPM-Security-Group-${random_string.id.id}"
  count       = var.AWS-security_group_id == "" ? 1 : 0
  vpc_id      = data.aws_subnet.subnet.vpc_id
  description = "A security group for Snowbit CSPM"
  tags        = merge(var.AWS-additional_tags,
    {
      Terraform-ID = random_string.id.id
    }
  )
  ingress {
    description = var.AWS-SSHIpAddress == "0.0.0.0/0" ?  "SSH from the world" : length(var.AWS-SSHIpAddress) > 0 ? "SSH from user provided IP - ${var.AWS-SSHIpAddress}" : "SSH from the creators public IP - ${data.http.external-ip-address.response_body}/32"
    cidr_blocks = [
      length(var.AWS-SSHIpAddress) > 0 ? var.AWS-SSHIpAddress : "${data.http.external-ip-address.response_body}/32"
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
resource "aws_iam_instance_profile" "CSPMInstanceProfile" {
  name = "CSPM-Instance-Profile-${random_string.id.id}"
  role = aws_iam_role.CSPMRole.name
  tags = merge(var.AWS-additional_tags,
    {
      Terraform-ID = random_string.id.id
    }
  )
}
resource "aws_iam_role" "CSPMRole" {
  name               = "CSPM-Role-${random_string.id.id}"
  assume_role_policy = jsonencode({

    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Sid       = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
  dynamic "inline_policy" {
    for_each = local.policies
    content {
      name = inline_policy.value["name"]
      policy = inline_policy.value["policy"]
    }
  }
  tags = merge(var.AWS-additional_tags,
    {
      Terraform-ID = random_string.id.id
    }
  )
}
resource "random_string" "id" {
  length  = 6
  special = false
  upper   = false
}
