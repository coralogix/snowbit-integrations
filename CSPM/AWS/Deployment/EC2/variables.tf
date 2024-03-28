// AWS
variable "AWS-additional_tags" {
  type    = map(string)
  default = {}
}
variable "AWS-instanceType" {
  type    = string
  validation {
    condition = length(var.AWS-instanceType) == 0 ? true : !can(regex("^(?:t[12]\\.(?:nano|micro|small)|c[67]g(?:d|n)?\\.medium|m[1367]g?d?\\.(?:small|medium)|r[67]gd?\\.medium|a1\\.medium|is4gen\\.medium|x2gd\\.medium)$", var.AWS-instanceType))
    error_message = "Invalid instance type"
  }
}
variable "AWS-Subnet_ID" {
  type        = string
  description = "Subnet for the EC2 instance"
  validation {
    condition     = can(regex("^subnet-\\w+", var.AWS-Subnet_ID))
    error_message = "Invalid subnet ID"
  }
}
variable "AWS-SSHKeyName" {
  type        = string
  default     = ""
  description = "The key to SSH the CSPM instance"
}
variable "AWS-DiskType" {
  type    = string
  default = "gp3"
  validation {
    condition = var.AWS-DiskType == "" ? true : can(regex("^(gp[23]|io[12])$", var.AWS-DiskType))
    error_message = "Invalid disk type."
  }
}
variable "AWS-SSHIpAddress" {
  type = string
  description = "The public IP address for SSH access to the EC2 instance"
  validation {
    condition = var.AWS-SSHIpAddress == "" ? true : can(regex("^(?:\\d{1,3}\\.){3}\\d{1,3}\\/\\d{1,2}$", var.AWS-SSHIpAddress))
    error_message = "IP address is not valid - expected x.x.x.x/x ."
  }
}
variable "AWS-ebs_encryption" {
  type        = bool
  default     = false
  description = "Decide id the EBS volume of the CSPM should be encrypted"
}
variable "AWS-public_instance" {
  type        = bool
  default     = true
  description = "Decide if the EC2 instance should pull a public IP address or not"
}
variable "AWS-security_group_id" {
  type        = string
  default     = ""
  description = "External security group to use instead of creating a new one"
}

// Coralogix
variable "Coralogix-GRPC_Endpoint" {
  type        = string
  default     = "EU1"
  description = "The address of the GRPC endpoint for the coralogix account"
  validation {
    condition     = can(regex("^(?:EU|AP|US)[12]$", var.Coralogix-GRPC_Endpoint))
    error_message = "Invalid GRPC endpoint."
  }
}
variable "Coralogix-applicationName" {
  type        = string
  description = "Application name for Coralogix account (no spaces)"
}
variable "Coralogix-subsystemName" {
  type        = string
  description = "Subsystem name for Coralogix account (no spaces)"
}
variable "Coralogix-PrivateKey" {
  type        = string
  description = "The API Key from the Coralogix account"
  sensitive   = true
  validation {
    condition     = can(regex("^\\w{8}\\-(?:(?:\\w{4})\\-){3}\\w{12}|^(cxt[p|h]_[a-zA-Z0-9]{30})$", var.Coralogix-PrivateKey))
    error_message = "Invalid Private Key."
  }
}
variable "Coralogix-alertAPIkey" {
  type        = string
  description = "The Alert API key from the Coralogix account"
  sensitive   = true
  validation {
    condition = var.Coralogix-alertAPIkey == "" ? true : can(regex("^\\w{8}-(?:\\w{4}-){3}\\w{12}$", var.Coralogix-alertAPIkey))
    error_message = "The alertAPIkey should be valid UUID string"
  }
}
variable "Coralogix-Company_ID" {
  type        = string
  description = "The Coralogix team company ID"
  validation {
    condition     = can(regex("^\\d{5,10}", var.Coralogix-Company_ID))
    error_message = "Invalid Company ID"
  }
}

// CSPM
variable "CSPM-TesterList" {
  type        = string
  default     = ""
  description = "Services for next scan"
}
variable "CSPM-multiAccountsARNs" {
  type        = list(string)
  default     = []
  description = "Optional - add the ARN for one additional account that you wish to scan - refer to the CSPM documentation https://coralogix.com/docs/cloud-security-posture-cspm/"
}
variable "CSPM-RegionList" {
  type    = string
  default = ""
}
