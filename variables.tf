variable "cloudtrail_bucket" {
  type = object({
    name   = string
    arn    = string
  })
  description = "Bucket containing the Cloudtrail logs that you want to process."
}

variable "excluded_accounts" {
  type        = list(string)
  description = "List of accounts that be excluded for scans on manual actions."
  default     = []
}


variable "included_accounts" {
  type        = list(string)
  description = "List of accounts that be scanned to manual actions."
  default     = []
}

variable event_processing_timeout {
  type = number
  description = "Maximum number of seconds the lambda is allowed to run and number of seconds events should be hidden in SQS after being picked up my Lambda."
  default = 60
}

variable log_retention_in_days {
  type = number
  description = "Number of days to keep CloudWatch logs"
  default = 30
}