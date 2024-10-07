# Get current AWS account information
data "aws_caller_identity" "current" {}

# Fetch the Route 53 zone for each domain
data "aws_route53_zone" "base_domain" {
  for_each     = toset(var.domain_names)
  name         = each.value
  private_zone = false
}

# Define the IAM policy for S3 bucket access
data "aws_iam_policy_document" "s3_policy" {
  statement {
    sid    = "AllowCloudFrontServicePrincipalReadOnly"
    effect = "Allow"
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "${aws_s3_bucket.static_site.arn}/*"
    ]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.static_site.arn]
    }
  }

  statement {
    sid    = "DenyAccessWithoutCustomHeader"
    effect = "Deny"
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "${aws_s3_bucket.static_site.arn}/*"
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "StringNotEquals"
      variable = "s3:ExistingObjectTag/CustomHeader"
      values   = [random_string.custom_header_value.result]
    }
  }

  statement {
    sid    = "DenyHTTPAccess"
    effect = "Deny"
    actions = [
      "s3:*"
    ]
    resources = [
      aws_s3_bucket.static_site.arn,
      "${aws_s3_bucket.static_site.arn}/*"
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid    = "AllowTerraformSVCAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
      "s3:DeleteObject"
    ]
    resources = [
      aws_s3_bucket.static_site.arn,
      "${aws_s3_bucket.static_site.arn}/*"
    ]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/svc_tf"]
    }
  }
}

# Create a zip file for the Lambda function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/disable_cloudfront.py"
  output_path = "${path.module}/disable_cloudfront_lambda.zip"
}
