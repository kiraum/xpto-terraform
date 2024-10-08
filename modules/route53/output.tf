output "ds_records" {
  value = { for k, v in aws_route53_key_signing_key.key_signing_key : k => v.ds_record }
}
