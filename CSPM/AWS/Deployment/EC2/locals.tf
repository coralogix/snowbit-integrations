// Maps
locals {
  grpc-endpoints-map = {
    EU1 = "ng-api-grpc.coralogix.com"
    EU2 = "ng-api-grpc.eu2.coralogix.com"
    AP1 = "ng-api-grpc.app.coralogix.in"
    AP2 = "ng-api-grpc.coralogixsg.com"
    US1 = "ng-api-grpc.coralogix.us"
    US2 = "ng-api-grpc.cx498.coralogix.cpm"
  }
}

// Instance Configurations
locals {
  user-pass              = replace(var.Coralogix-PrivateKey, "-", "")
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
    "-e CORALOGIX_ENDPOINT_HOST=${local.grpc-endpoints-map[var.Coralogix-GRPC_Endpoint]} ",
    "-e APPLICATION_NAME=${length(var.Coralogix-applicationName) > 0 ? var.Coralogix-applicationName : "CSPM"} ",
    "-e SUBSYSTEM_NAME=${length(var.Coralogix-subsystemName) > 0 ? var.Coralogix-subsystemName : "CSPM"} ",
    "-e TESTER_LIST=${var.CSPM-TesterList} ",
    "-e API_KEY=${var.Coralogix-PrivateKey} ",
    "-e REGION_LIST=${var.CSPM-RegionList} ",
    "-e ROLE_ARN_LIST=${join(",",var.CSPM-multiAccountsARNs)} ",
    "-e CORALOGIX_ALERT_API_KEY=${var.Coralogix-alertAPIkey} ",
    "-e COMPANY_ID=${var.Coralogix-Company_ID} ",
    "-v ~/.aws/credentials:/root/.aws/credentials coralogixrepo/snowbit-cspm\"; } | crontab -"
  ]
  )
}

// Policies
locals {
  policies = length(var.CSPM-multiAccountsARNs) != 0 ? {
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
            Resource : var.CSPM-multiAccountsARNs
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