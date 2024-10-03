variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "billing-report-lambda"
}
variable "ses_sender_email" {
  description = "Email address to send SES emails from"
  type        = string
}

variable "ses_recipient_email" {
  description = "Email address to receive SES emails"
  type        = string
}

variable "ses_domain" {
  description = "Domain for SES"
  type        = string
}