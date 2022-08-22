locals {
  project = "terraform-cloudwatch-log-management"
}

variable "invocation_rate" {
  type        = string
  default     = "rate(1 day)"
  description = "The rate at which the log management lambda will be triggered. Must be a string with rate() format"

  validation {
    condition     = can(regex("(^rate(\\([^)]+\\)))|(^cron(\\([^)]+\\)))", var.invocation_rate))
    error_message = "Please use an AWS rate() or cron() cron object for the invocation_rate https://docs.aws.amazon.com/lambda/latest/dg/services-cloudwatchevents-expressions.html."
  }
}

variable "cross_regions" {
  type        = string
  default     = "None"
  description = "Other AWS regions to configure Cloudwatch logs for, besides the region deployed into. Set to \"None\" for no multi-region functionality"
}

variable "retention_in_days" {
  type        = string
  default     = "7"
  description = "Retention in days to apply to each log group. Refer to https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/logs.html#CloudWatchLogs.Client.put_retention_policy for valid values"

  validation {
    condition     = can(regex("None|1|3|5|7|14|30|60|90|120|150|180|365|400|545|731|1827|3653", var.retention_in_days))
    error_message = "Please select a valid log retention period per Cloudwatch specifications. Use \"None\" if no retention management desired."
  }
}

variable "kms_key_alias" {
  type = string
  # default = "log-management-test"
  default     = "None"
  description = "The alias of the KMS key to use for CloudWatch log encryption. Must be already created in all desired regions."
}

variable "lambda_memory" {
  type        = number
  default     = 128
  description = "Amount of memory, in MB, to allocate to the Lambda function that will enforce the CloudWatch Log configuration. Increase if receiving timeout errors."
}

variable "lambda_timeout" {
  type        = number
  default     = 30
  description = "Amount of time, in seconds, for the Lambda function timeout. Increase if receiving timeout errors."
}

variable "allow_kms_disassociate" {
  type = string
  default = "False"
  description = "Whether or not to allow the log manager to remove KMS keys from log groups. Be warned this is a DANGEROUS operation, and can lead to you being unable to access previously encrypted logs if the associated KMS key is destroyed."

  validation {
    condition = can(regex("True|False", var.allow_kms_disassociate))
    error_message = "Please supply either \"True\" or \"False\"."
  }
}