variable "existing_lambda_to_coralogix_name" {
  type = string
  validation {
    condition     = length(var.existing_lambda_to_coralogix_name) > 0
    error_message = "The lambda name that sends to Coralogix cannot be empty"
  }
}
variable "eks_new_lambda_function_name" {
  type = string
}
variable "execution_rate" {
  type = string
  validation {
    condition = can(regex("^\\d+", var.execution_rate))
    error_message = "Rate must be a number"
  }
}