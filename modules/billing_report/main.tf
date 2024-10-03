terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0.0"
    }
  }
}

# Get current AWS account information
data "aws_caller_identity" "current" {}

# Define Lambda function for billing report
resource "aws_lambda_function" "billing_report" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = var.lambda_function_name
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.12"
  timeout          = 10

  environment {
    variables = {
      SES_SENDER_EMAIL    = var.ses_sender_email
      SES_RECIPIENT_EMAIL = var.ses_recipient_email
    }
  }

  tags = {
    Name = var.lambda_function_name
  }
}

# Create ZIP archive for Lambda function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

# Create IAM role for Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "billing-report-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Attach policy to Lambda IAM role
resource "aws_iam_role_policy" "lambda_policy" {
  name = "billing-report-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ce:GetCostAndUsage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
      }
    ]
  })
}

# Create CloudWatch event rules
resource "aws_cloudwatch_event_rule" "daily_trigger" {
  name                = "billing-report-daily-schedule"
  description         = "Triggers the billing report Lambda function daily at 7 AM CEST"
  schedule_expression = "cron(0 5 * * ? *)"
  tags = {
    Name = "billing-report-daily-schedule"
  }
}

resource "aws_cloudwatch_event_rule" "weekly_trigger" {
  name                = "billing-report-weekly-schedule"
  description         = "Triggers the billing report Lambda function weekly on Mondays at 7 AM CEST"
  schedule_expression = "cron(0 5 ? * MON *)"
  tags = {
    Name = "billing-report-weekly-schedule"
  }
}

resource "aws_cloudwatch_event_rule" "monthly_trigger" {
  name                = "billing-report-monthly-schedule"
  description         = "Triggers the billing report Lambda function monthly on the 1st day at 7 AM CEST"
  schedule_expression = "cron(0 5 1 * ? *)"
  tags = {
    Name = "billing-report-monthly-schedule"
  }
}

resource "aws_cloudwatch_event_rule" "yearly_trigger" {
  name                = "billing-report-yearly-schedule"
  description         = "Triggers the billing report Lambda function yearly on January 1st at 7 AM CEST"
  schedule_expression = "cron(0 5 1 1 ? *)"
  tags = {
    Name = "billing-report-yearly-schedule"
  }
}

# Set Lambda function as target for CloudWatch events with input transformers
resource "aws_cloudwatch_event_target" "daily_lambda_target" {
  rule      = aws_cloudwatch_event_rule.daily_trigger.name
  target_id = "TriggerBillingReportLambdaDaily"
  arn       = aws_lambda_function.billing_report.arn
  input_transformer {
    input_paths = {}
    input_template = jsonencode({
      time_period = "daily"
    })
  }
}

resource "aws_cloudwatch_event_target" "weekly_lambda_target" {
  rule      = aws_cloudwatch_event_rule.weekly_trigger.name
  target_id = "TriggerBillingReportLambdaWeekly"
  arn       = aws_lambda_function.billing_report.arn
  input_transformer {
    input_paths = {}
    input_template = jsonencode({
      time_period = "weekly"
    })
  }
}

resource "aws_cloudwatch_event_target" "monthly_lambda_target" {
  rule      = aws_cloudwatch_event_rule.monthly_trigger.name
  target_id = "TriggerBillingReportLambdaMonthly"
  arn       = aws_lambda_function.billing_report.arn
  input_transformer {
    input_paths = {}
    input_template = jsonencode({
      time_period = "monthly"
    })
  }
}

resource "aws_cloudwatch_event_target" "yearly_lambda_target" {
  rule      = aws_cloudwatch_event_rule.yearly_trigger.name
  target_id = "TriggerBillingReportLambdaYearly"
  arn       = aws_lambda_function.billing_report.arn
  input_transformer {
    input_paths = {}
    input_template = jsonencode({
      time_period = "yearly"
    })
  }
}

# Grant CloudWatch permission to invoke Lambda
resource "aws_lambda_permission" "allow_cloudwatch_daily" {
  statement_id  = "AllowExecutionFromCloudWatchDaily"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.billing_report.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_trigger.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_weekly" {
  statement_id  = "AllowExecutionFromCloudWatchWeekly"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.billing_report.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.weekly_trigger.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_monthly" {
  statement_id  = "AllowExecutionFromCloudWatchMonthly"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.billing_report.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.monthly_trigger.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_yearly" {
  statement_id  = "AllowExecutionFromCloudWatchYearly"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.billing_report.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.yearly_trigger.arn
}

# Create CloudWatch Log Group for Lambda function
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.billing_report.function_name}"
  retention_in_days = 7

  tags = {
    Name = "${var.lambda_function_name}-logs"
  }
}

resource "aws_ses_domain_identity" "ses_domain" {
  domain = var.ses_domain
}

resource "aws_ses_email_identity" "ses_email" {
  email = var.ses_sender_email
}

resource "aws_ses_domain_dkim" "ses_domain_dkim" {
  domain = aws_ses_domain_identity.ses_domain.domain
}

resource "aws_ses_domain_mail_from" "ses_domain_mail_from" {
  domain           = aws_ses_domain_identity.ses_domain.domain
  mail_from_domain = "mail.${aws_ses_domain_identity.ses_domain.domain}"
}
