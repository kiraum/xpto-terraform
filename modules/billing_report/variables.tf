variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "billing-report-lambda"
}

variable "sns_topic_name" {
  description = "Name of the SNS topic"
  type        = string
  default     = "billing-report-topic"
}

variable "email_subscription" {
  description = "Email address for SNS subscription"
  type        = string
}

variable "ruler_name" {
  description = "EventBridge ruler name"
  type        = string
  default     = "daily-billing-report-ruler"
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for storing processed dates"
  type        = string
  default     = "CostExplorerProcessedDates"
}
