variable "domains" {
  type = map(object({
    domain_name   = string
    comment       = string
    enable_dnssec = bool
    records = list(object({
      name    = string
      type    = string
      ttl     = optional(number)
      records = optional(list(string))
      alias = optional(object({
        name                   = string
        zone_id                = string
        evaluate_target_health = bool
      }))
    }))
  }))
}
