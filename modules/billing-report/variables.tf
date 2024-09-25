variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "billing-report-lambda"
}

variable "sns_topic_name" {
  description = "Name of the SNS topic"
  type        = string
  default     = "root-account-topic"
}

variable "email_subscription" {
  description = "Email address for SNS subscription"
  type        = string
}
