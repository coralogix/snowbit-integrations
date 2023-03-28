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
variable "okta_api_key" {
  type = string
}
variable "okta_domain" {
  type        = string
  description = "for example - 'example.okta.com'"
}

locals {
  okta_logstash_conf = <<EOF
wget https://artifacts.elastic.co/downloads/logstash/logstash-8.0.1-amd64.deb
dpkg -i logstash-8.0.1-amd64.deb
/usr/share/logstash/bin/logstash-plugin install logstash-input-okta_system_log
echo "input {
  okta_system_log {
    schedule       => { every => \"30s\" }
    limit          => 1000
    auth_token_key => \"${var.okta_api_key}\"
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
    url => \"${lookup(local.singles_map, var.coralogix_domain)}\"
    http_method => \"post\"
    headers => [\"private_key\", \"${var.coralogix_private_key}\"]
    format => \"json_batch\"
    codec => \"json\"
    mapping => {
        "applicationName" => \"${var.okta_application_name}\"
        "subsystemName" => \"${var.okta_subsystem_name}\"
        "computerName" => \"${base64decode("JXtob3N0fQ==")}\"
        "text" => \"${base64decode("JXtbQG1ldGFkYXRhXVtldmVudF19")}\"
    }
    http_compression => true
    automatic_retries => 5
    retry_non_idempotent => true
    connect_timeout => 30
    keepalive => false
    }
}" > /etc/logstash/conf.d/logstash.conf
systemctl restart logstash
EOF
  okta_user_data     = <<EOF
# Okta -->
echo '${local.okta_logstash_conf}' > /home/ubuntu/integrations/okta.conf
docker run -d --name okta -v /home/ubuntu/integrations/okta.conf:/usr/share/logstash/pipeline/logstash.conf docker.elastic.co/logstash/logstash:8.0.1
EOF
}
