# Get current AWS account information
data "aws_caller_identity" "current" {}

# Retrieve information about the current AWS region
data "aws_region" "current" {}

# Create ZIP archive for Lambda function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

# Retrieve the existing SSM parameter value
data "aws_ssm_parameter" "existing_slack_webhook_url" {
  name            = "/billing_report/slack_webhook_url"
  with_decryption = true # Ensure we get the decrypted value
}
