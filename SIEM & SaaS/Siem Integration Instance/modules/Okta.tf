variable "okta_application_name" {
  type        = string
  description = "Coralogix application name for Okta"
  default     = "Okta"
  validation {
    condition     = var.okta_application_name == "" ? true : can(regex("^[A-Za-z0-9\\s\\-\\_]+$", var.okta_application_name))
    error_message = "Invalid application name."
  }
}
variable "okta_subsystem_name" {
  type        = string
  description = "Coralogix subsystem name for Okta"
  default     = "Okta"
  validation {
    condition     = var.okta_subsystem_name == "" ? true : can(regex("^[A-Za-z0-9\\s\\-\\_]+$", var.okta_subsystem_name))
    error_message = "Invalid subsystem name."
  }
}
variable "okta_api_token" {
  type = string
}
variable "okta_domain" {
  type        = string
  description = "for example - 'example.okta.com'"
}

locals {
  okta_logstash_conf = <<EOF
input {
  okta_system_log {
    schedule       => {
      every => \"30s\"
    }
    limit          => 1000
    auth_token_key => \"${var.okta_api_token}\"
    hostname       => \"${var.okta_domain}\"
  }
}
filter {
  ruby {code => \"
                event.set('[@metadata][event]', event.to_json)
                \"}
}

output {
  http {
    url => \"https://${lookup(local.domain_endpoint_map, var.coralogix_domain)}/logs/rest/singles\"
    http_method => \"post\"
    headers => [\"private_key\", \"${var.coralogix_private_key}\"]
    format => \"json_batch\"
    codec => \"json\"
    mapping => {
      \"applicationName\" => \"${length(var.okta_application_name) > 0 ? var.okta_application_name : "Okta"}\"
      \"subsystemName\" => \"${length(var.okta_subsystem_name) > 0 ? var.okta_subsystem_name : "Okta"}\"
      \"computerName\" => \"${base64decode("JXtob3N0fQ==")}\"
      \"text\" => \"${base64decode("JXtbQG1ldGFkYXRhXVtldmVudF19")}\"
    }
    http_compression => true
    automatic_retries => 5
    retry_non_idempotent => true
    connect_timeout => 30
    keepalive => false
  }
}
EOF
  okta_user_data     = <<EOF

#
# Okta -->
#

wget https://artifacts.elastic.co/downloads/logstash/logstash-8.0.1-amd64.deb
dpkg -i logstash-8.0.1-amd64.deb
/usr/share/logstash/bin/logstash-plugin install logstash-input-okta_system_log
echo "${local.okta_logstash_conf}" > /etc/logstash/conf.d/logstash.conf
systemctl start logstash
EOF
}
