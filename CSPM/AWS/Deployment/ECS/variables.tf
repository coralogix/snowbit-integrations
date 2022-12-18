variable "container_Insights" {
  type    = string
  default = "disabled"
}
variable "GRPC_Endpoint_Location" {
  type        = string
  default     = "Europe"
  description = "The address of the GRPC endpoint for the coralogix account"
  validation {
    condition     = can(regex("^(Europe|Europe2|India|Singapore|US)$", var.GRPC_Endpoint_Location))
    error_message = "Invalid GRPC endpoint location."
  }
}
variable "applicationName" {
  type        = string
  description = "Application name for Coralogix account (no spaces)"
  default     = "Snowbit-CSPM"
}
variable "subsystemName" {
  type        = string
  description = "Subsystem name for Coralogix account (no spaces)"
  default     = "Snowbit-CSPM"
}
variable "PrivateKey" {
  type        = string
  description = "The API Key from the Coralogix account"
  sensitive   = true
  validation {
    condition     = can(regex("^\\w{8}-(?:\\w{4}-){3}\\w{12}$", var.PrivateKey))
    error_message = "The PrivateKey should be valid UUID string"
  }
}
variable "alertAPIkey" {
  type        = string
  description = "The Alert API key from the Coralogix account"
  sensitive   = true
  default     = ""
  validation {
    condition     = var.alertAPIkey == "" ? true : can(regex("^\\w{8}-(?:\\w{4}-){3}\\w{12}$", var.alertAPIkey))
    error_message = "The alertAPIkey should be valid UUID string"
  }
}
variable "Cluster_Name" {
  type    = string
  default = "Snowbit-Snowbit-CSPM"
}
variable "Company_ID" {
  type        = string
  description = "The Coralogix team company ID"
  validation {
    condition     = can(regex("^\\d{5,10}", var.Company_ID))
    error_message = "Invalid Company ID."
  }
}
variable "Role_ARN_List" {
  type        = list(string)
  description = "A comma separated list of the role ARNs of the additional accounts to scan."
  default     = []
}
variable "additional_tags" {
  type    = map(string)
  default = {}
}
variable "event_target_subnets" {
  description = "The subnets associated with the task or service."
  type        = list(string)
}
variable "event_target_ecs_target_security_groups" {
  description = "(Optional) The security groups associated with the task or service. If you do not specify a security group, the default security group for the VPC is used."
  type        = list(any)
  default     = null
}
variable "event_target_ecs_target_group" {
  description = "(Optional) Specifies an ECS task group for the task. The maximum length is 255 characters."
  default     = null
}
variable "event_target_ecs_target_platform_version" {
  description = "(Optional) Specifies the platform version for the task. Specify only the numeric portion of the platform version, such as 1.1.0. For more information about valid platform versions, see AWS Fargate Platform Versions. Default to LATEST."
  default     = "LATEST"
}
