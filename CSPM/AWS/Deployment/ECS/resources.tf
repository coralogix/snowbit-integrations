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
  container_definitions = local.container_definition
  family                = "${var.Cluster_Name}-${random_string.this.id}"
  tags                  = var.additional_tags
}
resource "aws_iam_role" "this" {
  for_each           = local.roles
  name               = each.value["role_name"]
  assume_role_policy = each.value["assume_role"]
  dynamic "inline_policy" {
    for_each = each.value["policies"]
    content {
      name   = inline_policy.key
      policy = inline_policy.value
    }
  }
  tags = var.additional_tags
}
resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/ecs/${var.Cluster_Name}-${random_string.this.id}"
  tags              = var.additional_tags
  retention_in_days = 1
}

// Scheduling
resource "aws_cloudwatch_event_rule" "this" {
  is_enabled          = true
  name                = "CSPM-scheduler"
  schedule_expression = "rate(2 minutes)"
  event_bus_name      = "default"
  tags                = {

  }
}
resource "aws_cloudwatch_event_target" "this" {
  rule           = aws_cloudwatch_event_rule.this.name
  event_bus_name = aws_cloudwatch_event_rule.this.event_bus_name
  target_id      = "CSPM-Schedule-Target"
  arn            = aws_ecs_cluster.this.arn
  role_arn       = aws_iam_role.schedule.arn
  ecs_target {
    group               = var.event_target_ecs_target_group
    launch_type         = "FARGATE"
    platform_version    = var.event_target_ecs_target_platform_version
    task_count          = 1
    task_definition_arn = aws_ecs_task_definition.this.arn
    network_configuration {
      subnets          = var.event_target_subnets
      security_groups  = var.event_target_ecs_target_security_groups
      assign_public_ip = true
    }
  }
}
resource "aws_iam_role" "schedule" {
  name               = "Snowbit-CSPM-schedule-Permissions-${random_string.this.id}"
  assume_role_policy = <<DOC
{
	"Version": "2012-10-17",
	"Statement": [{
		"Effect": "Allow",
		"Principal": {
			"Service": [
				"events.amazonaws.com"
			]
		},
		"Action": "sts:AssumeRole"
	}]
}
DOC
  inline_policy {
    name   = "schedule-permissions"
    policy = <<DOC
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": [
          "*"
        ],
      "Condition": {
        "StringLike": {
           "iam:PassedToService": "ecs-tasks.amazonaws.com"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecs:RunTask"
      ],
      "Resource": [
        "${replace(aws_ecs_task_definition.this.arn, "/:\\d+$/", ":*")}",
        "${replace(aws_ecs_task_definition.this.arn, "/:\\d+$/", "")}"
      ],
      "Condition": {
        "ArnLike": {
          "ecs:cluster": "${aws_ecs_cluster.this.arn}"
        }
      }
    }
  ]
}
DOC
  }
}

// Misc
resource "random_string" "this" {
  length  = 6
  upper   = false
  special = false
}
