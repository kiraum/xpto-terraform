terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0.0"
    }
  }
}

resource "aws_route53_zone" "zones" {
  for_each = var.domains
  name     = each.value.domain_name
  comment  = each.value.comment
}

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
