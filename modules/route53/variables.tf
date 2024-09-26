variable "hosted_zones" {
  type = map(object({
    domain_name = string
    comment     = string
    records = list(object({
      name    = string
      type    = string
      ttl     = number
      records = list(string)
    }))
  }))
}

