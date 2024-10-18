# Generate a random string for custom header value
resource "random_string" "custom_header_value" {
  length  = 32
  special = false
}

# Create an S3 bucket for static site hosting
resource "aws_s3_bucket" "static_site" {
  bucket = var.bucket_name
  tags   = var.tags
}

# Configure public access settings for the S3 bucket
resource "aws_s3_bucket_public_access_block" "static_site" {
  bucket = aws_s3_bucket.static_site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Set up versioning for the S3 bucket
resource "aws_s3_bucket_versioning" "static_site" {
  bucket = aws_s3_bucket.static_site.id
  versioning_configuration {
    status = "Disabled"
  }
}

# Configure server-side encryption for the S3 bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "static_site" {
  bucket = aws_s3_bucket.static_site.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Upload static site files to the S3 bucket
resource "aws_s3_object" "static_site_files" {
  for_each = fileset("${path.module}/content", "**/*")

  bucket = aws_s3_bucket.static_site.id
  key    = each.value
  source = "${path.module}/content/${each.value}"
  etag   = filemd5("${path.module}/content/${each.value}")

  content_type = lookup(var.mime_types, split(".", each.value)[length(split(".", each.value)) - 1], "application/octet-stream")

  tags = {
    CustomHeader = random_string.custom_header_value.result
  }
}

# Apply the IAM policy to the S3 bucket
resource "aws_s3_bucket_policy" "static_site" {
  bucket = aws_s3_bucket.static_site.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

# Create an SSL certificate
resource "aws_acm_certificate" "cert" {
  provider                  = aws.us_east_1
  domain_name               = var.domain_names[0]
  subject_alternative_names = concat(slice(var.domain_names, 1, length(var.domain_names)), [for domain in var.domain_names : "*.${domain}"])
  validation_method         = "DNS"
  tags                      = var.tags

  lifecycle {
    create_before_destroy = true
  }
}


# Set up DNS records for certificate validation
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
      domain = regex("^\\*?\\.?([^*]+)$", dvo.domain_name)[0]
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.base_domain[each.value.domain].zone_id
}



# Validate the SSL certificates
resource "aws_acm_certificate_validation" "cert" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}


# Create a CloudFront distribution for content delivery
resource "aws_cloudfront_distribution" "static_site" {
  provider = aws.us_east_1

  origin {
    domain_name              = aws_s3_bucket.static_site.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.static_site.id
    origin_id                = "S3-${var.bucket_name}"

    custom_header {
      name  = "X-Custom-Header"
      value = random_string.custom_header_value.result
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http2and3"
  default_root_object = "index.html"
  aliases             = concat(var.domain_names, [for domain in var.domain_names : "*.${domain}"])

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "S3-${var.bucket_name}"

    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers_policy.id

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    min_ttl                = 0
    default_ttl            = 300
    max_ttl                = 86400
  }

  ordered_cache_behavior {
    path_pattern     = "/.well-known/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${var.bucket_name}"

    response_headers_policy_id = aws_cloudfront_response_headers_policy.well_known_headers_policy.id

    forwarded_values {
      query_string = false
      headers      = ["Origin", "Content-Type"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  ordered_cache_behavior {
    path_pattern     = "/resume"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${var.bucket_name}"

    forwarded_values {
      query_string = false
      headers      = ["Origin"]
      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 300
    max_ttl                = 1200
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers_policy.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.url_rewrite.arn
    }
  }

  price_class = var.cloudfront_price_class

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = var.tags

  depends_on = [aws_acm_certificate_validation.cert]
}

# Configure origin access control for CloudFront
resource "aws_cloudfront_origin_access_control" "static_site" {
  provider                          = aws.us_east_1
  name                              = "${var.bucket_name}-oac"
  description                       = "OAC for ${join(", ", var.domain_names)}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Create a Lambda function to disable CloudFront distribution
resource "aws_lambda_function" "disable_cloudfront" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "disable_cloudfront_distribution_${var.bucket_name}"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "disable_cloudfront.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.12"
  timeout          = 10

  environment {
    variables = {
      DISTRIBUTION_ID = aws_cloudfront_distribution.static_site.id
      SNS_TOPIC_ARN   = aws_sns_topic.budget_alert.arn
    }
  }

  tags = {
    Name = "disable_cloudfront_distribution_${var.bucket_name}"
  }
}

# Define an IAM role for the Lambda function
resource "aws_iam_role" "lambda_exec" {
  name = "disable_cloudfront_lambda_role_${var.bucket_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Attach policies to the Lambda IAM role
resource "aws_iam_role_policy_attachment" "lambda_exec_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_exec.name
}

# Create custom policies for CloudFront access
resource "aws_iam_role_policy" "cloudfront_access" {
  name = "cloudfront_access_${var.bucket_name}"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "cloudfront:UpdateDistribution",
        "cloudfront:GetDistribution"
      ]
      Resource = aws_cloudfront_distribution.static_site.arn
    }]
  })
}

# Set up an SNS topic for budget alerts
resource "aws_sns_topic" "budget_alert" {
  name = "cloudfront-budget-alert-${var.bucket_name}"
}

# Create a budget for CloudFront usage
resource "aws_budgets_budget" "cloudfront" {
  name         = "cloudfront-monthly-budget-${var.bucket_name}"
  budget_type  = "COST"
  limit_amount = "1"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "Service"
    values = ["Amazon CloudFront"]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.budget_alert.arn]
  }
}

# Define an EventBridge rule for budget alerts
resource "aws_cloudwatch_event_rule" "budget_alert" {
  name        = "cloudfront-budget-alert-${var.bucket_name}"
  description = "Trigger when CloudFront budget threshold is exceeded"

  event_pattern = jsonencode({
    source      = ["aws.budgets"]
    detail-type = ["Budget Threshold Exceeded"]
    detail = {
      budgetName = [aws_budgets_budget.cloudfront.name]
    }
  })
}

# Set the Lambda function as the target for the EventBridge rule
resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.budget_alert.name
  target_id = "TriggerLambda"
  arn       = aws_lambda_function.disable_cloudfront.arn
}

# Grant EventBridge permission to invoke the Lambda function
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  function_name = aws_lambda_function.disable_cloudfront.function_name
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.budget_alert.arn
}

# Create custom policies for Lambda permissions
resource "aws_iam_role_policy" "lambda_permissions" {
  name = "cloudfront_sns_access_${var.bucket_name}"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudfront:GetDistributionConfig",
          "cloudfront:UpdateDistribution"
        ]
        Resource = aws_cloudfront_distribution.static_site.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.budget_alert.arn
      }
    ]
  })
}

# Create a CloudWatch log group for the Lambda function
resource "aws_cloudwatch_log_group" "disable_cloudfront_logs" {
  name              = "/aws/lambda/${aws_lambda_function.disable_cloudfront.function_name}"
  retention_in_days = 7

  tags = merge(
    var.tags,
    {
      Name = "${aws_lambda_function.disable_cloudfront.function_name}-logs"
    }
  )
}

# Define security headers policy for CloudFront
resource "aws_cloudfront_response_headers_policy" "security_headers_policy" {
  name    = "security-headers-policy-${var.bucket_name}"
  comment = "Security headers policy"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }
    content_security_policy {
      content_security_policy = "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; font-src 'self' data:; frame-ancestors 'self'; base-uri 'self'; form-action 'self';"
      override                = true
    }
    content_type_options {
      override = true
    }
  }
}

# Define headers policy for .well-known directory
resource "aws_cloudfront_response_headers_policy" "well_known_headers_policy" {
  name    = "well-known-headers-policy-${var.bucket_name}"
  comment = "Headers policy for .well-known directory"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }
    content_security_policy {
      content_security_policy = "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; font-src 'self' data:; frame-ancestors 'self'; base-uri 'self'; form-action 'self';"
      override                = true
    }
    content_type_options {
      override = true
    }
  }

  custom_headers_config {
    items {
      header   = "Content-Type"
      override = true
      value    = "text/plain"
    }
  }
}

# CloudFront function to rewrite /resume URLs to /resume/index.html
resource "aws_cloudfront_function" "url_rewrite" {
  name    = "url-rewrite"
  runtime = "cloudfront-js-1.0"
  comment = "URL rewrite for /resume"
  publish = true
  code    = <<EOF
function handler(event) {
    var request = event.request;
    var uri = request.uri;

    if (uri === '/resume' || uri === '/resume/') {
        request.uri = '/resume/index.html';
    }

    return request;
}
EOF
}
