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
  name                = var.ruler_name
  description         = "Triggers the billing report Lambda function daily at 7 AM CEST"
  schedule_expression = "cron(0 5 * * ? *)" # 7 AM CEST is 5 AM UTC

  tags = {
    Name = var.ruler_name
  }
}

# Set Lambda function as target for CloudWatch event
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.daily_trigger.name
  target_id = "TriggerBillingReportLambda"
  arn       = aws_lambda_function.billing_report.arn
}

# Grant CloudWatch permission to invoke Lambda
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.billing_report.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_trigger.arn
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

# Create IAM role for EventBridge scheduler
resource "aws_iam_role" "scheduler_role" {
  name = "billing-report-eventbridge-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# Attach policy to EventBridge scheduler IAM role
resource "aws_iam_role_policy" "scheduler_policy" {
  name = "billing-report-eventbridge-scheduler-policy"
  role = aws_iam_role.scheduler_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          "${aws_lambda_function.billing_report.arn}:*",
          aws_lambda_function.billing_report.arn
        ]
      }
    ]
  })
}

# Create EventBridge scheduler for daily billing report
resource "aws_scheduler_schedule" "daily_billing_report" {
  name       = "billing-report-daily-schedule"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = "cron(0 5 * * ? *)" # 7 AM CEST is 5 AM UTC

  target {
    arn      = aws_lambda_function.billing_report.arn
    role_arn = aws_iam_role.scheduler_role.arn
  }
}

resource "aws_kms_key" "lambda_key" {
  description                        = "Default key that protects my Lambda functions when no other key is defined"
  enable_key_rotation                = true
  bypass_policy_lockout_safety_check = false

  lifecycle {
    ignore_changes = [tags, tags_all]
  }
}

resource "aws_kms_key" "sns_key" {
  description                        = "Default key that protects my SNS data when no other key is defined"
  enable_key_rotation                = true
  bypass_policy_lockout_safety_check = false

  lifecycle {
    ignore_changes = [tags, tags_all]
  }
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
