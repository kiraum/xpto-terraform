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
      SNS_TOPIC_ARN = aws_sns_topic.billing_report.arn
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
          "sns:Publish"
        ]
        Resource = aws_sns_topic.billing_report.arn
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/${var.dynamodb_table_name}"
      }
    ]
  })
}

# Create CloudWatch event rule for daily trigger
resource "aws_cloudwatch_event_rule" "daily_trigger" {
  name                = "billing-report-daily-schedule"
  description         = "Triggers the billing report Lambda function daily at 7 AM CEST"
  schedule_expression = "cron(0 5 * * ? *)" # 7 AM CEST is 5 AM UTC
  tags = {
    Name = "billing-report-daily-schedule"
  }
}

# Create CloudWatch event rule for weekly trigger
resource "aws_cloudwatch_event_rule" "weekly_trigger" {
  name                = "billing-report-weekly-schedule"
  description         = "Triggers the billing report Lambda function weekly on Mondays at 7 AM CEST"
  schedule_expression = "cron(0 5 ? * MON *)" # 7 AM CEST on Mondays
  tags = {
    Name = "billing-report-weekly-schedule"
  }
}

# Create CloudWatch event rule for monthly trigger
resource "aws_cloudwatch_event_rule" "monthly_trigger" {
  name                = "billing-report-monthly-schedule"
  description         = "Triggers the billing report Lambda function monthly on the 1st day at 7 AM CEST"
  schedule_expression = "cron(0 5 1 * ? *)" # 7 AM CEST on the 1st day of each month
  tags = {
    Name = "billing-report-monthly-schedule"
  }
}

# Create CloudWatch event rule for yearly trigger
resource "aws_cloudwatch_event_rule" "yearly_trigger" {
  name                = "billing-report-yearly-schedule"
  description         = "Triggers the billing report Lambda function yearly on January 1st at 7 AM CEST"
  schedule_expression = "cron(0 5 1 1 ? *)" # 7 AM CEST on January 1st
  tags = {
    Name = "billing-report-yearly-schedule"
  }
}

# Set Lambda function as target for CloudWatch events
resource "aws_cloudwatch_event_target" "daily_lambda_target" {
  rule      = aws_cloudwatch_event_rule.daily_trigger.name
  target_id = "TriggerBillingReportLambdaDaily"
  arn       = aws_lambda_function.billing_report.arn
}

resource "aws_cloudwatch_event_target" "weekly_lambda_target" {
  rule      = aws_cloudwatch_event_rule.weekly_trigger.name
  target_id = "TriggerBillingReportLambdaWeekly"
  arn       = aws_lambda_function.billing_report.arn
}

resource "aws_cloudwatch_event_target" "monthly_lambda_target" {
  rule      = aws_cloudwatch_event_rule.monthly_trigger.name
  target_id = "TriggerBillingReportLambdaMonthly"
  arn       = aws_lambda_function.billing_report.arn
}

resource "aws_cloudwatch_event_target" "yearly_lambda_target" {
  rule      = aws_cloudwatch_event_rule.yearly_trigger.name
  target_id = "TriggerBillingReportLambdaYearly"
  arn       = aws_lambda_function.billing_report.arn
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

# Create SNS topic for billing report
resource "aws_sns_topic" "billing_report" {
  name = var.sns_topic_name

  tags = {
    Name = var.sns_topic_name
  }
}

# Create email subscription for SNS topic
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.billing_report.arn
  protocol  = "email"
  endpoint  = var.email_subscription
}

resource "aws_dynamodb_table" "cost_explorer_processed_dates" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "time_period"

  attribute {
    name = "time_period"
    type = "S"
  }

  tags = {
    Name = var.dynamodb_table_name
  }
}
