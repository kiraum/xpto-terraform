# Create Route53 hosted zones
resource "aws_route53_zone" "zones" {
  for_each = var.domains
  name     = each.value.domain_name
  comment  = each.value.comment
}

# Create KMS keys for DNSSEC
resource "aws_kms_key" "dnssec_key" {
  provider                 = aws.us_east_1
  for_each                 = { for k, v in var.domains : k => v if v.enable_dnssec }
  customer_master_key_spec = "ECC_NIST_P256"
  deletion_window_in_days  = 7
  key_usage                = "SIGN_VERIFY"
  policy = jsonencode({
    Statement = [
      {
        Action = [
          "kms:DescribeKey",
          "kms:GetPublicKey",
          "kms:Sign",
          "kms:Verify",
        ],
        Effect = "Allow"
        Principal = {
          Service = "dnssec-route53.amazonaws.com"
        }
        Resource = "*"
        Sid      = "Allow Route 53 DNSSEC Service"
      },
      {
        Action = "kms:*"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Resource = "*"
        Sid      = "Enable IAM User Permissions"
      },
    ]
    Version = "2012-10-17"
  })
}

# Create Route53 key signing keys
resource "aws_route53_key_signing_key" "key_signing_key" {
  for_each                   = { for k, v in var.domains : k => v if v.enable_dnssec }
  hosted_zone_id             = aws_route53_zone.zones[each.key].id
  key_management_service_arn = aws_kms_key.dnssec_key[each.key].arn
  name                       = "${each.value.domain_name}-key"
}

# Enable DNSSEC for hosted zones
resource "aws_route53_hosted_zone_dnssec" "dnssec" {
  for_each = { for k, v in var.domains : k => v if v.enable_dnssec }
  depends_on = [
    aws_route53_key_signing_key.key_signing_key
  ]
  hosted_zone_id = aws_route53_zone.zones[each.key].id
}

# Create Route53 records
resource "aws_route53_record" "records" {
  for_each = { for record in flatten([
    for domain, zone in var.domains : [
      for record in zone.records : {
        key = "${domain}-${record.name}-${record.type}"
        value = merge(record, {
          zone_id = aws_route53_zone.zones[domain].zone_id
        })
      }
    ]
  ]) : record.key => record.value }

  zone_id = each.value.zone_id
  name    = each.value.name
  type    = each.value.type

  dynamic "alias" {
    for_each = each.value.alias != null ? [each.value.alias] : []
    content {
      name                   = alias.value.name
      zone_id                = alias.value.zone_id
      evaluate_target_health = alias.value.evaluate_target_health
    }
  }

  ttl     = each.value.alias == null ? each.value.ttl : null
  records = each.value.alias == null ? each.value.records : null
}
