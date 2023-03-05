# API
resource "aws_cloudwatch_event_api_destination" "this" {
  name                = "connectionToCoralogix-${random_string.string.id}"
  connection_arn      = aws_cloudwatch_event_connection.this.arn
  http_method         = "POST"
  invocation_endpoint = lookup(var.coralogix_endpoint_map, var.coralogix_endpoint)
}
resource "aws_cloudwatch_event_connection" "this" {
  name               = "destinationToCoralogix"
  authorization_type = "API_KEY"
  description        = "Send logs to Coralogix"
  auth_parameters {
    api_key {
      key   = "x-amz-event-bridge-access-key"
      value = var.private_key
    }
    invocation_http_parameters {
      header {
        key   = "cx-application-name"
        value = var.application_name
      }
      header {
        key   = "cx-subsystem-name"
        value = var.subsystem_name
      }
    }
  }
}

# Rule
resource "aws_cloudwatch_event_rule" "this" {
  for_each       = var.event_pattern
  name           = "eventbridge-rule-to-coralogix-${each.key}-${random_string.string.id}"
  event_pattern  = lookup(var.event_pattern_map, each.key)
  event_bus_name = "default"
  tags           = merge(var.additional_tags, {
    Terraform-Execution-ID = random_string.string.id
  })
}
resource "aws_cloudwatch_event_target" "this" {
  for_each = var.event_pattern
  rule      = aws_cloudwatch_event_rule.this[each.key].name
  target_id = "eventbridge-target-${random_string.string.id}"
  arn       = aws_cloudwatch_event_api_destination.this.arn
  role_arn  = aws_iam_role.this.arn
}
resource "aws_iam_role" "this" {
  name               = "eventbridge-to-coralogix-${random_string.string.id}"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Sid       = "EventBridgeToCoralogix"
        Principal = {
          Service = "events.amazonaws.com"
        }
      },
    ]
  })
  inline_policy {
    name   = "eventbridge-to-coralogix-${random_string.string.id}"
    policy = jsonencode({
      "Version"   = "2012-10-17",
      "Statement" = [
        {
          "Effect"   = "Allow",
          "Action"   = "events:InvokeApiDestination",
          "Resource" = "arn:aws:events:${data.aws_region.current.id}:${data.aws_caller_identity.account.id}:api-destination/${aws_cloudwatch_event_api_destination.this.name}/*"
        }
      ]
    })
  }
  tags = merge(var.additional_tags, {
    Terraform-Execution-ID = random_string.string.id
  })
}

#Misc
resource "random_string" "string" {
  length  = 6
  special = false
  upper   = false
}