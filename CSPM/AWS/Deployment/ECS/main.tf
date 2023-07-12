variable "container_Insights" {
  type    = string
  default = "disabled"
}
variable "GRPC_Endpoint_Location" {
  type        = string
  default     = "Europe"
  description = "The address of the GRPC endpoint for the coralogix account"
  validation {
    condition     = can(regex("^(Europe|Europe2|India|Singapore|US)$", var.GRPC_Endpoint_Location))
    error_message = "Invalid GRPC endpoint location."
  }
}
variable "applicationName" {
  type        = string
  description = "Application name for Coralogix account (no spaces)"
  default     = "Snowbit-CSPM"
}
variable "subsystemName" {
  type        = string
  description = "Subsystem name for Coralogix account (no spaces)"
  default     = "Snowbit-CSPM"
}
variable "PrivateKey" {
  type        = string
  description = "The API Key from the Coralogix account"
  sensitive   = true
  validation {
    condition     = can(regex("^\\w{8}-(?:\\w{4}-){3}\\w{12}$", var.PrivateKey))
    error_message = "The PrivateKey should be valid UUID string"
  }
  default = "39736fd1-22e2-bb84-ed21-c3a59785e097"
}
variable "alertAPIkey" {
  type        = string
  description = "The Alert API key from the Coralogix account"
  sensitive   = true
  default     = ""
  validation {
    condition     = var.alertAPIkey == "" ? true : can(regex("^\\w{8}-(?:\\w{4}-){3}\\w{12}$", var.alertAPIkey))
    error_message = "The alertAPIkey should be valid UUID string"
  }
}
variable "Cluster_Name" {
  type    = string
  default = "Snowbit-Snowbit-CSPM"
}
variable "Company_ID" {
  type        = string
  description = "The Coralogix team company ID"
  validation {
    condition     = can(regex("^\\d{5,10}", var.Company_ID))
    error_message = "Invalid Company ID."
  }
}
variable "Role_ARN_List" {
  type    = string
  default = ""
}
variable "additional_tags" {
  type    = map(string)
  default = {}
}
variable "event_target_subnets" {
  description = "The subnets associated with the task or service."
  type        = list(string)
}
//Roles
locals {
  roles = {
    ecs_execution = {
      role_name   = "Snowbit-CSPM-ECS-Execution"
      policy_name = "ecs-task"
      assume_role = <<ARP
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": {
                "Service": [
                    "ecs-tasks.amazonaws.com"
                ]
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
ARP
      policy      = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": [
        "${aws_cloudwatch_log_group.this.arn}/*",
        ${aws_cloudwatch_log_group.this.arn}
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
      ]
      "Resources": "*"
    }
  ]
}
POLICY
    }
    task_permissions = {
      role_name = "Snowbit-CSPM-Task-Permissions"
      policy_name = "task-permissions"
      assume_role = <<ARP
{
	"Version": "2012-10-17",
	"Statement": [{
		"Effect": "Allow",
		"Principal": {
			"Service": [
				"ecs-tasks.amazonaws.com"
			]
		},
		"Action": "sts:AssumeRole"
	}]
}
ARP
      policy = data.http.policy.response_body
    }
  }
}
locals {
  env_vars      = <<EOT
[
    {
      "name": "PYTHONUNBUFFERED",
      "value": "1"
    },
    {
      "name": "CLOUD_PROVIDER",
      "value": "aws"
    },
    {
      "name": "AWS_DEFAULT_REGION",
      "value": "eu-west-1"
    },
    {
      "name": "CORALOGIX_ENDPOINT_HOST",
      "value": "${local.grpc_endpoint[var.GRPC_Endpoint_Location]}"
    },
    {
      "name": "APPLICATION_NAME",
      "value": "${var.applicationName}"
    },
    {
      "name": "SUBSYSTEM_NAME",
      "value": "${var.subsystemName}"
    },
    {
      "name": "COMPANY_ID",
      "value": "${var.Company_ID}"
    },
    {
      "name": "TESTER_LIST",
      "value": ""
    },
    {
      "name": "REGION_LIST",
      "value": ""
    },
    {
      "name": "ROLE_ARN_LIST",
      "value": "${var.Role_ARN_List}"
    },
    {
      "name": "API_KEY",
      "value": "${var.PrivateKey}"
    },
    {
      "name": "CORALOGIX_ALERT_API_KEY",
      "value": "${var.alertAPIkey}"
    }
]
EOT
  grpc_endpoint = {
    Europe    = "ng-api-grpc.coralogix.com"
    Europe2   = "ng-api-grpc.eu2.coralogix.com"
    India     = "ng-api-grpc.app.coralogix.in"
    Singapore = "ng-api-grpc.coralogixsg.com"
    US        = "ng-api-grpc.coralogix.us"
  }
}
data "aws_region" "this" {}
data "http" "policy" {
  url = "https://raw.githubusercontent.com/coralogix/snowbit-cspm-policies/master/cspm-aws-policy.json"
}
data "aws_caller_identity" "this" {}

// ECS
resource "aws_cloudwatch_log_group" "this" {
  name = "/aws/ecs/${var.Cluster_Name}-${random_string.this.id}"
  tags = var.additional_tags
}
resource "aws_ecs_cluster" "this" {
  name = var.Cluster_Name
  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"
      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.this.name
      }
    }
  }
  setting {
    name  = "containerInsights"
    value = var.container_Insights
  }
  tags = var.additional_tags
}
resource "aws_iam_role" "this" {
  for_each           = local.roles
  name               = each.value["role_name"]
  assume_role_policy = each.value["assume_role"]
  inline_policy {
    name   = each.value["policy_name"]
    policy = each.value["policy"]
  }
  tags = var.additional_tags
}
resource "aws_ecs_task_definition" "this" {
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.this["ecs_execution"].arn
  task_role_arn            = aws_iam_role.this["task_permissions"].arn
  runtime_platform {
    operating_system_family = "LINUX"
  }
  cpu                   = "2 vCPU"
  memory                = "4 GB"
  network_mode          = "awsvpc"
  container_definitions = <<DEFINITION
[
  {
    "name": "${var.Cluster_Name}-container",
    "image": "coralogixrepo/snowbit-Snowbit-CSPM:latest",
    "cpu": 2048,
    "memory": 4096,
    "essential": true,
    "environment": ${local.env_vars},
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${aws_cloudwatch_log_group.this.id}",
        "awslogs-region": "${data.aws_region.this.name}",
        "awslogs-stream-prefix": "${var.Cluster_Name}"
      }
    },
    "portMappings": [
      {
        "containerPort": 443,
        "hostPort": 443
      }
    ]
  }
]
DEFINITION
  family                = "${var.Cluster_Name}-${random_string.this.id}"
  tags                  = var.additional_tags
}

// Misc
resource "random_string" "this" {
  length  = 6
  upper   = false
  special = false
}