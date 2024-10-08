data "aws_acm_certificate" "website_cert_xpto_it" {
  provider = aws.us_east_1
  domain   = "xpto.it"
  statuses = ["ISSUED"]
}
