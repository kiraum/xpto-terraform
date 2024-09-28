# Route53 Module

This module manages AWS Route53 hosted zones and DNS records for the XPTO project.

## Features

- Creates and manages Route53 hosted zones
- Supports multiple DNS record types
- Allows for easy configuration of alias records
- Integrates with other AWS services through DNS management

## Usage

To use this module in your Terraform configuration:

```hcl
module "route53" {
  source = "../../modules/route53"

  hosted_zones = {
    "example_com" = {
      domain_name = "example.com"
      comment     = "Hosted zone for example.com"
      records = [
        {
          name    = ""
          type    = "A"
          alias = {
            name                   = "d1234abcdef.cloudfront.net"
            zone_id                = "Z2FDTNDATAQYW2"
            evaluate_target_health = false
          }
        },
        {
          name    = "www"
          type    = "CNAME"
          ttl     = 300
          records = ["example.com"]
        }
      ]
    }
  }
}
```

## Input Variables

- hosted_zones: A map of hosted zones to create, each containing:
- domain_name: The domain name for the hosted zone
- comment: A comment for the hosted zone
- records: A list of DNS records to create in the zone

## Outputs

This module doesn't define any outputs, but you can add them as needed.

## Requirements

- Terraform >= 1.0.0
- AWS provider >= 4.0.0

## Notes

This module creates both the hosted zones and the DNS records within them.
It supports both alias and non-alias records.
The module uses dynamic blocks to handle alias records efficiently.
For more details on implementation, refer to the main.tf file in the route53 module directory.
