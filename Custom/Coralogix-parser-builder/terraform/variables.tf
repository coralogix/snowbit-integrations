variable "coralogix_api_key" {
  description = "Coralogix API key (or set TF_VAR_coralogix_api_key env var)"
  type        = string
  sensitive   = true
}

variable "coralogix_endpoint" {
  description = "Coralogix endpoint/domain (e.g. cx498.coralogix.com)"
  type        = string
  default     = "cx498.coralogix.com"
}
