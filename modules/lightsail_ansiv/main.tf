resource "aws_lightsail_container_service" "ansiv" {
  name        = var.container_name
  power       = var.bundle_id
  scale       = 1
  is_disabled = false

  private_registry_access {
    ecr_image_puller_role {
      is_active = true
    }
  }

  public_domain_names {
    certificate {
      certificate_name = aws_lightsail_certificate.ansiv.name
      domain_names     = sort(var.custom_domain_name)
    }
  }

  tags = {
    Name = var.container_name
  }
}

resource "aws_lightsail_container_service_deployment_version" "ansiv" {
  service_name = aws_lightsail_container_service.ansiv.name

  container {
    container_name = var.container_name
    image          = var.container_image

    command = ["serve", "file", "/app/resume.json", "--port", "8080"]

    ports = {
      8080 = "HTTP"
    }
  }

  public_endpoint {
    container_name = var.container_name
    container_port = 8080



    health_check {
      healthy_threshold   = 2
      unhealthy_threshold = 2
      timeout_seconds     = 10
      interval_seconds    = 300
      path                = "/"
      success_codes       = "200-499"
    }
  }
}

resource "aws_lightsail_certificate" "ansiv" {
  name                      = "${var.container_name}-cert"
  domain_name               = var.custom_domain_name[0]
  subject_alternative_names = slice(var.custom_domain_name, 1, length(var.custom_domain_name))
}

# Lambda function for disabling Lightsail
resource "aws_lambda_function" "disable_lightsail" {
  filename         = "${path.module}/disable_lightsail.zip"
  source_code_hash = data.archive_file.disable_lightsail.output_base64sha256
  function_name    = "disable-lightsail-lambda"
  role             = aws_iam_role.disable_lightsail_lambda.arn
  handler          = "disable_lightsail.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30

  environment {
    variables = {
      CONTAINER_SERVICE_NAME = aws_lightsail_container_service.ansiv.name
      SNS_TOPIC_ARN          = aws_sns_topic.lightsail_alerts.arn
    }
  }
}

# Archive file for Lambda
data "archive_file" "disable_lightsail" {
  type        = "zip"
  source_file = "${path.module}/disable_lightsail.py"
  output_path = "${path.module}/disable_lightsail.zip"
}

# IAM role for Lambda
resource "aws_iam_role" "disable_lightsail_lambda" {
  name = "disable-lightsail-lambda-role"

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

# IAM policy for Lambda
resource "aws_iam_role_policy" "disable_lightsail_lambda" {
  name = "disable-lightsail-lambda-policy"
  role = aws_iam_role.disable_lightsail_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lightsail:UpdateContainerService",
          "sns:Publish"
        ]
        Resource = [
          aws_lightsail_container_service.ansiv.arn,
          aws_sns_topic.lightsail_alerts.arn
        ]
      }
    ]
  })
}

# SNS Topic for alerts
resource "aws_sns_topic" "lightsail_alerts" {
  name = "lightsail-alerts"
}

# CloudWatch Logs policy
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.disable_lightsail_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Add Lambda permission for AWS Budgets
resource "aws_lambda_permission" "allow_budgets" {
  statement_id  = "AllowBudgetsInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.disable_lightsail.function_name
  principal     = "budgets.amazonaws.com"
}

# Update budget notification to use notification_type
resource "aws_budgets_budget" "lightsail" {
  name         = "lightsail-monthly-budget"
  budget_type  = "COST"
  limit_amount = var.monthly_budget_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator = "GREATER_THAN"
    threshold           = 100
    threshold_type      = "PERCENTAGE"
    notification_type   = "FORECASTED"

    subscriber_sns_topic_arns = [aws_sns_topic.lightsail_alerts.arn]
  }
}
