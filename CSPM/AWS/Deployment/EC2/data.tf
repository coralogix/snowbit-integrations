data "aws_subnet" "subnet" {
  id = var.AWS-Subnet_ID
}
data "http" "external-ip-address" {
  url = "http://ifconfig.me"
}
data "http" "policy" {
  url = "https://raw.githubusercontent.com/coralogix/snowbit-cspm-policies/master/AWS/cspm-aws-policy.json"
}
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"]
}