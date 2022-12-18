data "aws_region" "current" {}
data "aws_subnet" "subnet" {
  id = var.Subnet_ID
}
data "http" "external-ip-address" {
  url = "http://ifconfig.me"
}
data "http" "policy" {
  url = "https://raw.githubusercontent.com/coralogix/snowbit-cspm-policies/master/AWS/cspm-aws-policy.json"
}
