resource "aws_route53_zone" "zones" {
  for_each = var.hosted_zones

  name    = each.value.domain_name
  comment = each.value.comment
}

resource "aws_route53_record" "records" {
  for_each = { for record in flatten([
    for zone_key, zone in var.hosted_zones : [
      for record in zone.records : {
        zone_key = zone_key
        record   = record
      }
    ]
  ]) : "${record.zone_key}-${record.record.name}-${record.record.type}" => record }

  zone_id = aws_route53_zone.zones[each.value.zone_key].zone_id
  name    = each.value.record.name
  type    = each.value.record.type
  ttl     = each.value.record.ttl
  records = each.value.record.records
}

