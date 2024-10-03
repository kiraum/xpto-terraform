# Output the ARN of the Lambda function
output "lambda_function_arn" {
  description = "The ARN of the billing report Lambda function"
  value       = aws_lambda_function.billing_report.arn
}

# Output the name of the Lambda function
output "lambda_function_name" {
  description = "The name of the billing report Lambda function"
  value       = aws_lambda_function.billing_report.function_name
}

# Output the ARN of the IAM role used by the Lambda function
output "lambda_role_arn" {
  description = "The ARN of the IAM role used by the Lambda function"
  value       = aws_iam_role.lambda_role.arn
}

# Output the name of the CloudWatch event rule
output "cloudwatch_event_rule_name" {
  description = "The name of the CloudWatch event rule for triggering the Lambda function"
  value       = aws_cloudwatch_event_rule.daily_trigger.name
}

# Output the AWS account ID
output "aws_account_id" {
  description = "The AWS account ID where the resources are deployed"
  value       = data.aws_caller_identity.current.account_id
}

output "ses_sender_email" {
  description = "The email address used to send SES emails"
  value       = var.ses_sender_email
}

output "recipient_email" {
  description = "The email address receiving emails"
  value       = var.recipient_email
}
