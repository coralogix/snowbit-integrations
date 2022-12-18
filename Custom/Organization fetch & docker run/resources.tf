resource "aws_instance" "cspm-instance" {
  ami                         = lookup(var.ubuntu-amis-map, data.aws_region.current.name)
  instance_type               = length(var.instanceType) > 0 ? var.instanceType : "t3.small"
  key_name                    = var.SSHKeyName
  iam_instance_profile        = aws_iam_instance_profile.CSPMInstanceProfile.id
  associate_public_ip_address = var.public_instance
  subnet_id                   = var.Subnet_ID
  vpc_security_group_ids      = [
    var.security_group_id != "" ? var.security_group_id : aws_security_group.CSPMSecurityGroup[0].id
  ]
  user_data = <<EOT
#!/bin/bash
apt-get update
echo -e "${local.user-pass}\n${local.user-pass}" | /usr/bin/passwd ubuntu
${local.aws}
curl https://raw.githubusercontent.com/coralogix/snowbit-integrations/master/Custom/scripts/docker.sh | sh
${local.boto3_install}
echo ${base64encode(data.local_file.script.content)} | base64 -d > /root/code.py

crontab -l | { cat; echo "*/10 * * * * /usr/bin/python3 /root/code.py --default-region=${data.aws_region.current.name} --excluded-accounts=${var.excluded_accounts} --secret-name=${var.secret_name} --company-id=${var.Company_ID} --role-name=${var.additional_role_name} --api-key=${var.PrivateKey} --alert_api-key=${var.alertAPIkey} --application-name=${length(var.applicationName) > 0 ? var.applicationName : "CSPM"} --subsystem-name=${length(var.subsystemName) > 0 ? var.subsystemName : "CSPM"} --grpc-endpoint=${lookup(var.grpc-endpoints-map, var.GRPC_Endpoint)} --tester-list=${var.TesterList} --region-list=${var.RegionList}"; } | crontab -
crontab -l | { cat; echo "0 0 * * * echo "" > /root/docker-logs.log"; } | crontab -
EOT
  root_block_device {
    volume_type = length(var.DiskType) > 0 ? var.DiskType : "gp3"
    encrypted   = var.ebs_encryption
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }
  tags = merge(var.additional_tags,
    {
      Name         = "Snowbit CSPM"
      Terraform-ID = random_string.id.id
    },
  )
}
resource "aws_security_group" "CSPMSecurityGroup" {
  name        = "CSPM-Security-Group-${random_string.id.id}"
  count       = var.security_group_id == "" ? 1 : 0
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
      data.aws_subnet.subnet.cidr_block,
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
resource "aws_iam_instance_profile" "CSPMInstanceProfile" {
  name = "CSPM-Instance-Profile-${random_string.id.id}"
  role = aws_iam_role.CSPMRole.name
  tags = merge(var.additional_tags,
    {
      Terraform-ID = random_string.id.id
    }
  )
}
resource "aws_iam_role" "CSPMRole" {
  name = "CSPM-Role-${random_string.id.id}"
  tags = merge(var.additional_tags,
    {
      Terraform-ID = random_string.id.id
    }
  )
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
  inline_policy {
    name   = "Organization"
    policy = jsonencode({
      Version   = "2012-10-17"
      Statement = [
        {
          "Sid" : "CSPMAssumeRole",
          "Effect" : "Allow",
          "Action" : "organizations:ListAccounts",
          "Resource" : "*"
        }
      ]
    })
  }
}
resource "aws_iam_policy" "CSPMPolicy" {
  name   = "CSPM-Policy-${random_string.id.id}"
  policy = data.http.policy.response_body
  tags   = merge(var.additional_tags,
    {
      Terraform-ID = random_string.id.id
    }
  )
}

resource "aws_iam_policy" "CSPMAssumeRolePolicy" {
  name   = "CSPM-Assume-Role-Policy-${random_string.id.id}"
  count  = length(var.multiAccountsARNs) > 10 ? 1 : 0
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        "Sid" : "CSPMAssumeRole",
        "Effect" : "Allow",
        "Action" : "sts:AssumeRole",
        "Resource" : split(",", var.multiAccountsARNs)
      }
    ]
  })
  tags = merge(var.additional_tags,
    {
      Terraform-ID = random_string.id.id
    }
  )
}
resource "aws_iam_policy_attachment" "CSPMPolicy" {
  name       = "CSPMPolicy-attach"
  policy_arn = aws_iam_policy.CSPMPolicy.arn
  roles      = [aws_iam_role.CSPMRole.name]
}
resource "aws_iam_policy_attachment" "CSPMAssumeRolePolicy" {
  count      = length(var.multiAccountsARNs) > 10 ? 1 : 0
  name       = "CSPMAssumeRolePolicy-attach"
  policy_arn = aws_iam_policy.CSPMAssumeRolePolicy[0].arn
  roles      = [aws_iam_role.CSPMRole.name]

}
resource "random_string" "id" {
  length  = 6
  special = false
  upper   = false
}

############# NEW ADDITIONS
resource "aws_lambda_function" "role_updater" {
  function_name = "CSPM-Role-Organization-Updater-${random_string.id.id}"
  role          = aws_iam_role.role_updater.arn
  filename      = "lambda.py.zip"
  runtime       = "python3.9"
  handler       = "lambda.lambda_handler"
  environment {
    variables = {
      role_name                    = aws_iam_role.CSPMRole.name
      additional_account_role_name = var.additional_role_name
    }
  }
  tags = merge(var.additional_tags,
    {
      Terraform-ID = random_string.id.id
    },
  )
}
resource "aws_iam_role" "role_updater" {
  name               = "CSPM-Role-Updater-${random_string.id.id}"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Sid       = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
  inline_policy {
    name   = "policy"
    policy = jsonencode({
      Version   = "2012-10-17"
      Statement = [
        {
          Action = [
            "organizations:ListAccounts",
            "iam:DeleteRolePolicy",
            "iam:PutRolePolicy"
          ]
          Effect   = "Allow"
          Resource = "*"
        },
      ]
    })
  }
  tags = merge(var.additional_tags,
    {
      Terraform-ID = random_string.id.id
    },
  )
}
resource "aws_lambda_permission" "this" {
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.role_updater.function_name
  principal      = "events.amazonaws.com"
  statement_id   = "invoke-${random_string.id.id}"
  source_arn     = aws_cloudwatch_event_rule.role_updater.arn
  source_account = data.aws_caller_identity.this.account_id
}
resource "aws_cloudwatch_event_rule" "role_updater" {
  name                = "CSPM-Role-Updater"
  description         = "Timing lambda trigger to update the role of the CSPM for all organization accounts"
  schedule_expression = var.lambda_rate
  tags                = var.additional_tags
}
resource "aws_cloudwatch_event_target" "this" {
  arn  = aws_lambda_function.role_updater.arn
  rule = aws_cloudwatch_event_rule.role_updater.name
}
resource "aws_iam_policy" "secret-manager" {
  count  = length(var.secret_name) > 0 ? 1 : 0
  name   = "secret-manager-access"
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        "Sid" : "CSPMAssumeRole",
        "Effect" : "Allow",
        "Action" : "secretsmanager:GetSecretValue",
        "Resource" : data.aws_secretsmanager_secret.secret[0].arn
      }
    ]
  })
}
resource "aws_iam_policy_attachment" "secret-manager" {
  count  = length(var.secret_name) > 0 ? 1 : 0
  name       = "secret-manager-access-attach"
  policy_arn = aws_iam_policy.secret-manager[0].arn
  roles      = [aws_iam_role.CSPMRole.name]
}