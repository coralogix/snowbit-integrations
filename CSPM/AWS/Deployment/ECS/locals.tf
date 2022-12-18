//Roles
locals {
  roles = {
    ecs_execution = {
      role_name   = "Snowbit-CSPM-ECS-Execution-${random_string.this.id}"
      assume_role = <<ARP
{
	"Version": "2012-10-17",
	"Statement": [{
		"Sid": "",
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
      policies    = {
        ecs-task = <<POLICY
{
	"Version": "2012-10-17",
	"Statement": [{
			"Effect": "Allow",
			"Action": [
				"logs:CreateLogStream",
				"logs:PutLogEvents"
			],
			"Resource": [
				"${aws_cloudwatch_log_group.this.arn}:*",
				"${aws_cloudwatch_log_group.this.arn}"
			]
		},
		{
			"Effect": "Allow",
			"Action": [
				"ecr:GetAuthorizationToken",
				"ecr:BatchCheckLayerAvailability",
				"ecr:GetDownloadUrlForLayer",
				"ecr:BatchGetImage"
			],
			"Resource": "*"
		}
	]
}
POLICY
      }
    }
    task_permissions = {
      role_name   = "Snowbit-CSPM-Task-Permissions-${random_string.this.id}"
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
      policies    = local.multi_account_not_used ? {
        cspm-permissions = data.http.policy.response_body
      } : {
        cspm-permissions               = data.http.policy.response_body
        additional-account-assume-role = local.multi_account_not_used ? null : jsonencode({
          Version   = "2012-10-17"
          Statement = [
            {
              "Sid" : "CSPMAdditionalAccounts",
              "Effect" : "Allow",
              "Action" : "sts:AssumeRole",
              Resource : var.Role_ARN_List
            }
          ]
        })
      }
    }
  }
}
locals {
  multi_account_not_used = length(var.Role_ARN_List) != 0 ? false : true
  container_definition = <<DEFINITION
[
  {
    "name": "${var.Cluster_Name}-container",
    "image": "coralogixrepo/snowbit-cspm:latest",
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
  env_vars               = <<EOT
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
      "value": "${join(",", var.Role_ARN_List)}"
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
  grpc_endpoint          = {
    Europe    = "ng-api-grpc.coralogix.com"
    Europe2   = "ng-api-grpc.eu2.coralogix.com"
    India     = "ng-api-grpc.app.coralogix.in"
    Singapore = "ng-api-grpc.coralogixsg.com"
    US        = "ng-api-grpc.coralogix.us"
  }
}
