# Terraform configuration block
terraform {
  # Specify the minimum required Terraform version
  required_version = ">= 1.0.0"

  # Define required providers
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0.0"
    }
  }
}

# Default AWS provider configuration
provider "aws" {
  region = var.aws_region

  # Set default tags for all resources created by this provider
  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
      Project     = var.project
      CostCenter  = var.cost_center
    }
  }
}

# US East 1 (N. Virginia) AWS provider configuration
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  # Set default tags for all resources created by this provider
  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
      Project     = var.project
      CostCenter  = var.cost_center
    }
  }
}

# Billing report module
module "billing_report" {
  source = "../../modules/billing_report"

  lambda_function_name      = "billing-report-lambda"
  recipient_emails          = ["tfgoncalves@xpto.it"]
  enable_email_notification = true
  enable_slack_notification = true
  slack_webhook_url         = var.slack_webhook_url
  daily_cost_threshold      = "0.15"
  weekly_cost_threshold     = "1.00"
  monthly_cost_threshold    = "5.00"
  yearly_cost_threshold     = "60.00"
}


# Route53 module for DNS management
module "route53" {
  source = "../../modules/route53"

  domains = {
    "kiraum_it" = {
      domain_name   = "kiraum.it"
      comment       = "kiraum.it hosted zone"
      enable_dnssec = true
      records = [
        # A record for root domain
        {
          name = ""
          type = "A"
          alias = {
            name                   = "dpop20p5u4112.cloudfront.net"
            zone_id                = "Z2FDTNDATAQYW2"
            evaluate_target_health = false
          }
        },
        # AAAA record for root domain
        {
          name = ""
          type = "AAAA"
          alias = {
            name                   = "dpop20p5u4112.cloudfront.net"
            zone_id                = "Z2FDTNDATAQYW2"
            evaluate_target_health = false
          }
        },
        # A record for www domain
        {
          name = "www"
          type = "A"
          alias = {
            name                   = "dpop20p5u4112.cloudfront.net"
            zone_id                = "Z2FDTNDATAQYW2"
            evaluate_target_health = false
          }
        },
        # AAAA record for www domain
        {
          name = "www"
          type = "AAAA"
          alias = {
            name                   = "dpop20p5u4112.cloudfront.net"
            zone_id                = "Z2FDTNDATAQYW2"
            evaluate_target_health = false
          }
        },
        # DS record
        {
          name    = "www"
          type    = "DS"
          ttl     = 300
          records = ["59271 13 2 8FDD803780E68CC89617D1FE69E50E0D26E3A65B2ECE3434AF433D0611C04FB9"]
        },
        # TLSA record
        {
          name    = "_443._tcp"
          type    = "TXT"
          ttl     = 300
          records = ["3 1 1 ${local.tlsa_hash_xpto_it}"]
        },
        # MX records for email routing
        {
          name    = ""
          type    = "MX"
          ttl     = 300
          records = ["10 mail.protonmail.ch", "20 mailsec.protonmail.ch"]
        },
        # TXT records for various verifications and SPF
        {
          name = ""
          type = "TXT"
          ttl  = 300
          records = [
            # kiraum.it
            "protonmail-verification=4fd8734e27858d5bb727e0b811f506185942856d",
            "v=spf1 include:_spf.protonmail.ch ~all"
          ]
        },
        # DMARC record
        {
          name    = "_dmarc"
          type    = "TXT"
          ttl     = 300
          records = ["v=DMARC1; p=quarantine"]
        },
        # DKIM records for ProtonMail
        {
          name    = "protonmail._domainkey"
          type    = "CNAME"
          ttl     = 300
          records = ["protonmail.domainkey.dempd74kuxcjabpnbahdxnyoscyzm34xj6e5of6vyqwjrw64bwqoq.domains.proton.ch."]
        },
        {
          name    = "protonmail2._domainkey"
          type    = "CNAME"
          ttl     = 300
          records = ["protonmail2.domainkey.dempd74kuxcjabpnbahdxnyoscyzm34xj6e5of6vyqwjrw64bwqoq.domains.proton.ch."]
        },
        {
          name    = "protonmail3._domainkey"
          type    = "CNAME"
          ttl     = 300
          records = ["protonmail3.domainkey.dempd74kuxcjabpnbahdxnyoscyzm34xj6e5of6vyqwjrw64bwqoq.domains.proton.ch."]
        },
        # lightsail
        {
          name    = "ansiv"
          type    = "CNAME"
          ttl     = 300
          records = [module.lightsail_ansiv.container_url]
        },
        # lightsail cert
        {
          name    = module.lightsail_ansiv.domain_validation_records["ansiv.kiraum.it"].name
          type    = module.lightsail_ansiv.domain_validation_records["ansiv.kiraum.it"].type
          ttl     = 300
          records = [module.lightsail_ansiv.domain_validation_records["ansiv.kiraum.it"].value]
        }

      ]
    },
    "xpto_it" = {
      domain_name   = "xpto.it"
      comment       = "xpto.it hosted zone"
      enable_dnssec = true
      records = [
        # A record for root domain
        {
          name = ""
          type = "A"
          alias = {
            name                   = "dpop20p5u4112.cloudfront.net"
            zone_id                = "Z2FDTNDATAQYW2"
            evaluate_target_health = false
          }
        },
        # AAAA record for root domain
        {
          name = ""
          type = "AAAA"
          alias = {
            name                   = "dpop20p5u4112.cloudfront.net"
            zone_id                = "Z2FDTNDATAQYW2"
            evaluate_target_health = false
          }
        },
        # A record for www domain
        {
          name = "www"
          type = "A"
          alias = {
            name                   = "dpop20p5u4112.cloudfront.net"
            zone_id                = "Z2FDTNDATAQYW2"
            evaluate_target_health = false
          }
        },
        # AAAA record for www domain
        {
          name = "www"
          type = "AAAA"
          alias = {
            name                   = "dpop20p5u4112.cloudfront.net"
            zone_id                = "Z2FDTNDATAQYW2"
            evaluate_target_health = false
          }
        },
        # DS record
        {
          name    = "www"
          type    = "DS"
          ttl     = 300
          records = ["4612 13 2 344E99D76D844AFA04ACCEF9DB12F6C13FDD8C878BB97D77EB1B526423A20968"]
        },
        # TLSA record
        {
          name    = "_443._tcp"
          type    = "TXT"
          ttl     = 300
          records = ["3 1 1 ${local.tlsa_hash_xpto_it}"]
        },
        # MX records for email routing
        {
          name    = ""
          type    = "MX"
          ttl     = 300
          records = ["10 mail.protonmail.ch", "20 mailsec.protonmail.ch"]
        },
        # TXT records for various verifications and SPF
        {
          name = ""
          type = "TXT"
          ttl  = 300
          records = [
            # xpto.it
            "protonmail-verification=afef88a17d1a02a65dbb087c7f748fe9bcd01a32",
            "v=spf1 include:_spf.protonmail.ch ~all"
          ]
        },
        # DMARC record
        {
          name    = "_dmarc"
          type    = "TXT"
          ttl     = 300
          records = ["v=DMARC1; p=quarantine"]
        },
        # DKIM records for ProtonMail
        {
          name    = "protonmail._domainkey"
          type    = "CNAME"
          ttl     = 300
          records = ["protonmail.domainkey.d5cgr4quagzmaa5rqmmtnppt6lo46zuzu2zjylpuruv5luk4vmkuq.domains.proton.ch."]
        },
        {
          name    = "protonmail2._domainkey"
          type    = "CNAME"
          ttl     = 300
          records = ["protonmail2.domainkey.d5cgr4quagzmaa5rqmmtnppt6lo46zuzu2zjylpuruv5luk4vmkuq.domains.proton.ch."]
        },
        {
          name    = "protonmail3._domainkey"
          type    = "CNAME"
          ttl     = 300
          records = ["protonmail3.domainkey.d5cgr4quagzmaa5rqmmtnppt6lo46zuzu2zjylpuruv5luk4vmkuq.domains.proton.ch."]
        },
        # lightsail
        {
          name    = "ansiv"
          type    = "CNAME"
          ttl     = 300
          records = [module.lightsail_ansiv.container_url]
        },
        # lightsail cert
        {
          name    = module.lightsail_ansiv.domain_validation_records["ansiv.xpto.it"].name
          type    = module.lightsail_ansiv.domain_validation_records["ansiv.xpto.it"].type
          ttl     = 300
          records = [module.lightsail_ansiv.domain_validation_records["ansiv.xpto.it"].value]
        }

      ]
    }
  }

  # Specify providers for this module
  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }
}

# Static website module
module "static_website" {
  source = "../../modules/static_website"

  bucket_name            = "xpto-static-website-bucket"
  domain_names           = ["xpto.it", "kiraum.it"]
  cloudfront_price_class = "PriceClass_100"

  tags = {
    Environment = var.environment
    Project     = var.project
  }

  # Specify providers for this module
  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }
}


# Lightsail module
module "lightsail_ansiv" {
  source = "../../modules/lightsail_ansiv"

  container_name       = "ansiv"
  container_image      = ":ansiv.resume.7"
  availability_zone    = "${var.aws_region}a"
  bundle_id            = "nano"
  custom_domain_name   = ["ansiv.xpto.it", "ansiv.kiraum.it"]
  monthly_budget_limit = "10"
}
