output "route53_dnssec_keys" {
  value       = module.route53.dnssec_key_signing_keys
  description = "DNSSEC key signing key details for Route53 zones"
}
