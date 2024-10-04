variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "billing-report-lambda"
}
#variable "ses_sender_email" {
#  description = "Email address to send SES emails from"
#  type        = string
#}

variable "recipient_emails" {
  description = "List of email addresses to receive emails"
  type        = list(string)
}

#variable "ses_domain" {
#  description = "Domain for SES"
#  type        = string
#}

variable "notification_service" {
  description = "The notification service to use (SNS or SES)"
  type        = string
  default     = "SNS"
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
