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

# Output the ARN of the SNS topic
output "sns_topic_arn" {
  description = "The ARN of the SNS topic for billing reports"
  value       = aws_sns_topic.billing_report.arn
}

# Output the name of the CloudWatch event rule
output "cloudwatch_event_rule_name" {
  description = "The name of the CloudWatch event rule for triggering the Lambda function"
  value       = aws_cloudwatch_event_rule.daily_trigger.name
}

# Output the ARN of the EventBridge scheduler role
output "scheduler_role_arn" {
  description = "The ARN of the IAM role used by the EventBridge scheduler"
  value       = aws_iam_role.scheduler_role.arn
}

# Output the name of the EventBridge scheduler
output "scheduler_name" {
  description = "The name of the EventBridge scheduler for the daily billing report"
  value       = aws_scheduler_schedule.daily_billing_report.name
}

# Output the email address subscribed to the SNS topic
output "sns_subscription_email" {
  description = "The email address subscribed to the billing report SNS topic"
  value       = var.email_subscription
}

# Output the AWS account ID
output "aws_account_id" {
  description = "The AWS account ID where the resources are deployed"
  value       = data.aws_caller_identity.current.account_id
}
