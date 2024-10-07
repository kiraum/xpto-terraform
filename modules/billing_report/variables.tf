variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "billing-report-lambda"
}

variable "recipient_emails" {
  description = "List of email addresses to receive emails"
  type        = list(string)
}

variable "enable_email_notification" {
  description = "Enable email notifications via SNS"
  type        = bool
  default     = false
}

variable "daily_cost_threshold" {
  description = "The daily cost threshold for billing alerts"
  type        = string
  default     = "0.01"
}

variable "weekly_cost_threshold" {
  description = "The weekly cost threshold for billing alerts"
  type        = string
  default     = "0.01"
}

variable "monthly_cost_threshold" {
  description = "The monthly cost threshold for billing alerts"
  type        = string
  default     = "0.01"
}

variable "yearly_cost_threshold" {
  description = "The yearly cost threshold for billing alerts"
  type        = string
  default     = "0.01"
}

variable "enable_slack_notification" {
  description = "Enable Slack webhook notification"
  type        = bool
  default     = false
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications"
  type        = string
}
