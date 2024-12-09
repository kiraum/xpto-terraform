output "ds_records" {
  value = { for k, v in aws_route53_key_signing_key.key_signing_key : k => v.ds_record }
}

output "dnssec_key_signing_keys" {
  value = {
    for k, v in aws_route53_key_signing_key.key_signing_key : k => {
      key_tag                    = v.key_tag
      digest_algorithm_mnemonic  = v.digest_algorithm_mnemonic
      digest_algorithm_type      = v.digest_algorithm_type
      digest_value               = v.digest_value
      public_key                 = v.public_key
      signing_algorithm_mnemonic = v.signing_algorithm_mnemonic
      signing_algorithm_type     = v.signing_algorithm_type
    }
  }
  description = "DNSSEC key signing key details for each domain"
}
