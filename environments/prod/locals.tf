locals {
  tlsa_hash_kiraum = base64encode(sha256(data.aws_acm_certificate.website_cert_kiraum.certificate))
}

locals {
  tlsa_hash_xpto_it = base64encode(sha256(data.aws_acm_certificate.website_cert_xpto_it.certificate))
}
