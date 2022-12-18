variable "additional_tags" {
  type    = map(string)
  default = {}
}
variable "instanceType" {
  type    = string
  validation {
    condition = length(var.instanceType) == 0 ? true : !can(regex("^(?:t[12]\\.(?:nano|micro|small)|c[67]g(?:d|n)?\\.medium|m[1367]g?d?\\.(?:small|medium)|r[67]gd?\\.medium|a1\\.medium|is4gen\\.medium|x2gd\\.medium)$", var.instanceType))
    error_message = "Invalid instance type"
  }
}
variable "Subnet_ID" {
  type        = string
  description = "Subnet for the EC2 instance"
  validation {
    condition     = can(regex("^subnet-\\w+", var.Subnet_ID))
    error_message = "Invalid subnet ID"
  }
}
variable "SSHKeyName" {
  type        = string
  default     = ""
  description = "The key to SSH the CSPM instance"
}
variable "DiskType" {
  type    = string
  validation {
    condition = var.DiskType == "" ? true : can(regex("^(gp[23]|io[12])$", var.DiskType))
    error_message = "Invalid disk type"
  }
}
variable "SSHIpAddress" {
  type = string
  description = "The public IP address for SSH access to the EC2 instance"
  validation {
    condition = var.SSHIpAddress == "" ? true : can(regex("^(?:\\d{1,3}\\.){3}\\d{1,3}\\/\\d{1,2}$", var.SSHIpAddress))
    error_message = "IP address is not valid - expected x.x.x.x/x"
  }
}
variable "GRPC_Endpoint" {
  type        = string
  default     = "Europe"
  description = "The address of the GRPC endpoint for the coralogix account"
  validation {
    condition     = can(regex("^(Europe|Europe2|India|Singapore|US)$", var.GRPC_Endpoint))
    error_message = "Invalid GRPC endpoint"
  }
}
variable "applicationName" {
  type        = string
  description = "Application name for Coralogix account (no spaces)"
}
variable "subsystemName" {
  type        = string
  description = "Subsystem name for Coralogix account (no spaces)"
}
variable "TesterList" {
  type        = string
  default     = ""
  description = "Services for next scan"
}
variable "RegionList" {
  type    = string
  default = ""
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
  validation {
    condition = var.alertAPIkey == "" ? true : can(regex("^\\w{8}-(?:\\w{4}-){3}\\w{12}$", var.alertAPIkey))
    error_message = "The alertAPIkey should be valid UUID string"
  }
}
variable "Company_ID" {
  type        = string
  description = "The Coralogix team company ID"
  validation {
    condition     = can(regex("^\\d{5,10}", var.Company_ID))
    error_message = "Invalid Company ID"
  }
}
variable "ebs_encryption" {
  type        = bool
  default     = false
  description = "Decide id the EBS volume of the CSPM should be encrypted"
}
variable "public_instance" {
  type        = bool
  default     = true
  description = "Decide if the EC2 instance should pull a public IP address or not"
}
variable "security_group_id" {
  type        = string
  default     = ""
  description = "External security group to use instead of creating a new one"
}
variable "multiAccountsARNs" {
  type        = list(string)
  default     = []
  description = "Optional - add the ARN for one additional account that you wish to scan - refer to the CSPM documentation https://coralogix.com/docs/cloud-security-posture-cspm/"
}
