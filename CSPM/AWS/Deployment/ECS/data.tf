data "aws_region" "this" {}
data "http" "policy" {
  url = "https://raw.githubusercontent.com/coralogix/snowbit-cspm-policies/master/AWS/cspm-aws-policy.json"
}
data "aws_caller_identity" "this" {}
