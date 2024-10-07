# Static Website Module

This module sets up a static website hosted on AWS S3 with CloudFront distribution, SSL certificate, and budget alerts.

## Features

- S3 bucket for static content hosting
- CloudFront distribution with custom domain and SSL
- ACM certificate for HTTPS
- Route53 DNS configuration
- Lambda function to disable CloudFront distribution on budget alerts
- SNS notifications for budget alerts and CloudFront disabling events
- CloudWatch logs for Lambda function

## Usage

```hcl
module "static_website" {
  source = "path/to/modules/static_website"

  bucket_name            = "your-unique-bucket-name"
  domain_name            = "example.com"
  cloudfront_price_class = "PriceClass_100"
  tags = {
    Environment = "Production"
    Project     = "MyWebsite"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| bucket_name | The name of the S3 bucket to create | `string` | n/a | yes |
| domain_name | The domain name for the static website | `string` | n/a | yes |
| cloudfront_price_class | The price class for the CloudFront distribution | `string` | n/a | yes |
| tags | A map of tags to add to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| website_url | The CloudFront distribution domain name |
| s3_bucket_name | The name of the S3 bucket |
| cloudfront_distribution_id | The ID of the CloudFront distribution |
| acm_certificate_arn | The ARN of the ACM certificate |

## Notes

- The module includes a Lambda function (`disable_cloudfront.py`) that automatically disables the CloudFront distribution when the budget alert is triggered.
- SNS notifications are sent for budget alerts and when the CloudFront distribution is disabled.
- The S3 bucket is configured with appropriate security policies and public access blocks.
- CloudFront is set up with custom headers for additional security.
- A monthly budget of $1 USD is set for CloudFront usage with an alert at 80% threshold.
- The Lambda function logs are retained for 7 days in CloudWatch.

Order to create => AWS R53 => AWS CF => TLSA

## Requirements

- Terraform >= 1.0.0
- AWS provider >= 4.0.0
- Archive provider >= 2.0.0
- Random provider >= 3.0.0

## License

This module is released under the GNU Affero General Public License v3.0.
