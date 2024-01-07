data "aws_region" "current" {}
data "aws_caller_identity" "this" {}
data "aws_subnet" "subnet" {
  id = var.Subnet_ID
}
data "http" "external-ip-address" {
  url = "http://ipinfo.io/ip"
  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "${self.url} returned an unhealthy status code. Consider using the 'STA-external-IP-address-for-management' variable to define access IP to the STA."
    }
    postcondition {
      condition     = can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", self.response_body))
      error_message = "${self.url} returned a respnse that is not IPv4. Consider using the 'STA-external-IP-address-for-management' variable to define access IP to the STA."
    }
  }
}
data "http" "policy" {
  url = "https://raw.githubusercontent.com/coralogix/snowbit-cspm-policies/master/AWS/cspm-aws-policy.json"
}
data "local_file" "script" {
  filename = "./code.py"
}
data "aws_secretsmanager_secret" "secret" {
  count = length(var.secret_name) > 0 ? 1 : 0
  name = var.secret_name
}