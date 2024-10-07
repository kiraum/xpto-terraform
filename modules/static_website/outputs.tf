output "website_url" {
  description = "The CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.static_site.domain_name
}

output "s3_bucket_name" {
  description = "The name of the S3 bucket"
  value       = aws_s3_bucket.static_site.id
}

output "cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.static_site.id
}

output "acm_certificate_arns" {
  description = "The ARNs of the ACM certificates"
  value       = { for domain, cert in aws_acm_certificate.cert : domain => cert.arn }
}
