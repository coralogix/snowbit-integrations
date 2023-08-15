// Maps
locals {
  ubuntu-amis-map = {
    "us-east-1"      = "ami-08c40ec9ead489470",
    "us-east-2"      = "ami-097a2df4ac947655f",
    "us-west-1"      = "ami-02ea247e531eb3ce6",
    "us-west-2"      = "ami-017fecd1353bcc96e",
    "ap-south-1"     = "ami-062df10d14676e201",
    "ap-northeast-1" = "ami-09a5c873bc79530d9",
    "ap-northeast-2" = "ami-0e9bfdb247cc8de84",
    "ap-northeast-3" = "ami-08c2ee02329b72f26",
    "ap-southeast-1" = "ami-07651f0c4c315a529",
    "ap-southeast-2" = "ami-09a5c873bc79530d9",
    "ca-central-1"   = "ami-0a7154091c5c6623e",
    "eu-central-1"   = "ami-0caef02b518350c8b",
    "eu-west-1"      = "ami-096800910c1b781ba",
    "eu-west-2"      = "ami-0f540e9f488cfa27d",
    "eu-west-3"      = "ami-0493936afbe820b28",
    "eu-north-1"     = "ami-0efda064d1b5e46a5",
    "sa-east-1"      = "ami-04b3c23ec8efcc2d6"
  }
  grpc-endpoints-map = {
    Europe    = "ng-api-grpc.coralogix.com"
    Europe2   = "ng-api-grpc.eu2.coralogix.com"
    India     = "ng-api-grpc.app.coralogix.in"
    Singapore = "ng-api-grpc.coralogixsg.com"
    US        = "ng-api-grpc.coralogix.us"
  }
}

// Instance Configurations
locals {
  user-pass              = replace(var.PrivateKey, "-", "")
  docker_install         = <<DOC
apt update
apt-get remove docker docker-engine docker.io containerd runc
apt-get install ca-certificates curl gnupg lsb-release -y
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null\nsudo apt update
apt update
apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
usermod -aG docker ubuntu
newgrp docker
DOC
  docker_command_in_cron = join("", [
    "crontab -l | { cat; echo \"*/10 * * * * docker rm snowbit-cspm ; ",
    "docker rmi coralogixrepo/snowbit-cspm ; ",
    "docker run --name snowbit-cspm -d ",
    "-e PYTHONUNBUFFERED=1 ",
    "-e CLOUD_PROVIDER=aws ",
    "-e AWS_DEFAULT_REGION=eu-west-1 ",
    "-e CORALOGIX_ENDPOINT_HOST=${local.grpc-endpoints-map[var.GRPC_Endpoint]} ",
    "-e APPLICATION_NAME=${length(var.applicationName) > 0 ? var.applicationName : "CSPM"} ",
    "-e SUBSYSTEM_NAME=${length(var.subsystemName) > 0 ? var.subsystemName : "CSPM"} ",
    "-e TESTER_LIST=${var.TesterList} ",
    "-e API_KEY=${var.PrivateKey} ",
    "-e REGION_LIST=${var.RegionList} ",
    "-e ROLE_ARN_LIST=${join(",",var.multiAccountsARNs)} ",
    "-e CORALOGIX_ALERT_API_KEY=${var.alertAPIkey} ",
    "-e COMPANY_ID=${var.Company_ID} ",
    "-v ~/.aws/credentials:/root/.aws/credentials coralogixrepo/snowbit-cspm\"; } | crontab -"
  ]
  )
}

// Policies
locals {
  policies = length(var.multiAccountsARNs) != 0 ? {
    CSPMPolicy = {
      name   = "CSPM-Policy-${random_string.id.id}"
      policy = data.http.policy.response_body
    }
    CSPMAssumeRolePolicy = {
      name   = "CSPM-Assume-Role-Policy-${random_string.id.id}"
      policy = jsonencode({
        Version   = "2012-10-17"
        Statement = [
          {
            "Sid" : "CSPMAssumeRole",
            "Effect" : "Allow",
            "Action" : "sts:AssumeRole",
            Resource : var.multiAccountsARNs
          }
        ]
      })
    }
  } : {
    CSPMPolicy = {
      name   = "CSPM-Policy-${random_string.id.id}"
      policy = data.http.policy.response_body
    }
  }
}