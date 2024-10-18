output "container_url" {
  value       = trimprefix(trimsuffix(aws_lightsail_container_service.ansiv.url, "/"), "https://")
  description = "The clean domain name of the Lightsail container service"
}

output "domain_validation_records" {
  value = {
    for dvo in aws_lightsail_certificate.ansiv.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      value = dvo.resource_record_value
      type  = dvo.resource_record_type
    }
  }
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function that disables Lightsail"
  value       = aws_lambda_function.disable_lightsail.arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for Lightsail alerts"
  value       = aws_sns_topic.lightsail_alerts.arn
}
