data "aws_acm_certificate" "website_cert_kiraum" {
  provider = aws.us_east_1
  domain   = "kiraum.it"
  statuses = ["ISSUED"]
}

data "aws_acm_certificate" "website_cert_xpto_it" {
  provider = aws.us_east_1
  domain   = "xpto.it"
  statuses = ["ISSUED"]
}
