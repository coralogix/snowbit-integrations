variable "crowdstrike_application_name" {
  type        = string
  description = "Coralogix application name for CrowdStrike"
  default     = "CrowdStrike"
  validation {
    condition     = var.crowdstrike_application_name == "" ? true : can(regex("^[A-Za-z0-9\\s\\-\\_]+$", var.crowdstrike_application_name))
    error_message = "Invalid application name."
  }
}
variable "crowdstrike_subsystem_name" {
  type        = string
  description = "Coralogix subsystem name for CrowdStrike"
  default     = "CrowdStrike"
  validation {
    condition     = var.crowdstrike_subsystem_name == "" ? true : can(regex("^[A-Za-z0-9\\s\\-\\_]+$", var.crowdstrike_subsystem_name))
    error_message = "Invalid subsystem name."
  }
}
variable "crowdstrike_client_secret" {
  type      = string
  sensitive = true
}
variable "crowdstrike_client_id" {
  type      = string
  sensitive = true
}
variable "crowdstrike_api_url" {
  type    = string
  default = "api.crowdstrike.com"
  validation {
    condition     = var.crowdstrike_api_url == "" ? true : can(regex("^api(?:\\.|\\.us-2\\.|\\.laggar\\.gcw\\.|\\.eu-1\\.)crowdstrike\\.com", var.crowdstrike_api_url))
    error_message = "Invalid API URL."
  }
}

locals {
  crowdstrike_fluent-bit_conf = <<EOF
[SERVICE]
    flush        1
    log_level    info
    parsers_file parsers.conf
[INPUT]
    name                 tail
    path                 /fluent-bit/cs-log.log
    multiline.parser     multiline_parser
[FILTER]
    Name              parser
    Match             *
    Key_Name          log
    Parser            json_parser
[FILTER]
    Name        nest
    Match       *
    Operation   nest
    Wildcard    *
    Nest_under  text
[FILTER]
    Name    modify
    Match   *
    Add    applicationName ${var.crowdstrike_application_name}
    Add    subsystemName ${var.crowdstrike_subsystem_name}
    Add    computerName CrowdStrike
[OUTPUT]
    Name                  http
    Match                 *
    Host                  ${lookup(local.domain_endpoint_map, var.coralogix_domain)}
    Port                  443
    URI                   /logs/rest/singles
    Format                json_lines
    TLS                   On
    Header                private_key ${var.coralogix_private_key}
    compress              gzip
    Retry_Limit           10
EOF
  crowdstrike_parser_file     = <<EOF
[MULTILINE_PARSER]
    name          multiline_parser
    type          regex
    flush_timeout 1000
    #
    # Regex rules for multiline parsing
    # ---------------------------------
    #
    # configuration hints:
    #
    #  - first state always has the name: start_state
    #  - every field in the rule must be inside double quotes
    #
    # rules |   state name  | regex pattern                  | next state
    # ------|---------------|--------------------------------------------
    rule      "start_state"   "/^{/"                        "cont"
    rule      "cont"          "/^[^{]/"                     "cont"
[PARSER]
    name json_parser
    format json
EOF
  crowdstrike_user_data       = <<EOF

#
# CrowdStrike -->
#

wget https://snowbit-shared-resources.s3.eu-west-1.amazonaws.com/crowdstrike-cs-falconhoseclient_2.14.0_amd64.deb
sudo dpkg -i crowdstrike-cs-falconhoseclient_2.12.0_amd64.deb
echo '${local.crowdstrike_fluent-bit_conf}' > /home/ubuntu/integrations/crowdstrike.conf
echo '${local.crowdstrike_parser_file}' > /home/ubuntu/integrations/crowdstrike_parsers.conf
sed -i '3s/.*/api_url = https:\/\/${var.crowdstrike_api_url}\/sensors\/entities\/datafeed\/v2/' /opt/crowdstrike/etc/cs.falconhoseclient.cfg
sed -i '4s/.*/request_token_url = https:\/\/${var.crowdstrike_api_url}\/oauth2\/token/' /opt/crowdstrike/etc/cs.falconhoseclient.cfg
sed -i '11s/.*/client_id = ${var.crowdstrike_client_id}/' /opt/crowdstrike/etc/cs.falconhoseclient.cfg
sed -i '13s/.*/client_secret = ${var.crowdstrike_client_secret}/' /opt/crowdstrike/etc/cs.falconhoseclient.cfg
docker run -d --name crowdstrike \
-v /home/ubuntu/integrations/crowdstrike.conf:/fluent-bit/etc/fluent-bit.conf \
-v /home/ubuntu/integrations/crowdstrike_parsers.conf:/fluent-bit/etc/parsers.conf fluent/fluent-bit \
-v /var/log/crowdstrike/falconhoseclient/output:/fluent-bit/cs-log.log fluent/fluent-bit
EOF
}
