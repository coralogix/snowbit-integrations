variable "jumpcloud_application_name" {
  type        = string
  description = "Coralogix application name for JumpCloud"
  default     = "JumpCloud"
  validation {
    condition     = var.jumpcloud_application_name == "" ? true : can(regex("^[A-Za-z0-9\\s\\-\\_]+$", var.jumpcloud_application_name))
    error_message = "Invalid application name."
  }
}
variable "jumpcloud_subsystem_name" {
  type        = string
  description = "Coralogix subsystem name for JumpCloud"
  default     = "JumpCloud"
  validation {
    condition     = var.jumpcloud_subsystem_name == "" ? true : can(regex("^[A-Za-z0-9\\s\\-\\_]+$", var.jumpcloud_subsystem_name))
    error_message = "Invalid subsystem name."
  }
}
variable "jumpcloud_api_key" {
  type = string
  description = "The API key for JumpCloud read only admin access"
  validation {
    condition = var.jumpcloud_api_key == "" ? true : can(regex("^[a-f0-9]{40}$", var.jumpcloud_api_key))
    error_message = "Invalid JumpCloud API key."
  }
}

locals {
  jumpcloud_conf      = <<EOF
{
  "jumpcloud": {
    "api_key": "${var.jumpcloud_api_key}",
    "json_depth": 10,
    "timestamp_field_name": "timestamp",
    "initial_days_back": -1
  },
  "siem": {
    "format": "json_lines",
    "url": "https://${lookup(local.singles_map, var.coralogix_domain)}/logs/datastream",
    "method": "POST",
    "headers": {
      "private_key": "${var.coralogix_private_key}"
    },
    "content_type": "application/json",
    "batch_size": 1000,
    "batch_delay_milliseconds": 100,
    "timestamp_field_name": "jc_timestamp",
    "custom_log_fields": {
      "reqHost": "${length(var.jumpcloud_application_name) > 0 ? var.jumpcloud_application_name : "JumpCloud"}",
      "customField": "${length(var.jumpcloud_subsystem_name) > 0 ? var.jumpcloud_subsystem_name : "JumpCloud"}",
      "severity": "info"
    }
  }
}
EOF
  jumpcloud_user_data = <<EOF
# JumpCloud -->
apt-get install -y wget apt-transport-https software-properties-common
wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb"
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install -y powershell
pwsh -command "Install-Module -Name JumpCloud -Scope AllUsers -Force"
wget -O /home/ubuntu/integrations/jumpcloud.ps1 https://raw.githubusercontent.com/coralogix/snowbit-integrations/master/SIEM%20%26%20SaaS/JumpCloud/JC-DI2SIEM.ps1
echo '${local.jumpcloud_conf}' > /home/ubuntu/integrations/jumpcloud_conf.json
echo '{
    "LogLevel": "Critical"
}' > /opt/microsoft/powershell/7/powershell.config.json
crontab -l | { cat; echo "* * * * * /usr/bin/pwsh /home/ubuntu/integrations/jumpcloud.ps1 -config_file:/home/ubuntu/integrations/jumpcloud_conf.json 2>&1"; } | crontab -
EOF
}
