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

  lambda_function_name = "billing-report-lambda"
  # too much work to enable SES on AWS just for this notification
  #ses_sender_email       = "root@kiraum.it"
  #ses_domain             = "kiraum.it"
  recipient_emails          = ["tfgoncalves@xpto.it"]
  notification_service      = "SNS"
  enable_slack_notification = true
  slack_webhook_url         = var.slack_webhook_url
  daily_cost_threshold      = "0.01"
  weekly_cost_threshold     = "1.00"
  monthly_cost_threshold    = "5.00"
  yearly_cost_threshold     = "60.00"
}

# Route53 module for DNS management
module "route53" {
  source = "../../modules/route53"

  domains = {
    "kiraum_it" = {
      domain_name = "kiraum.it"
      comment     = "kiraum.it hosted zone"
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
        # TLSA record
        {
          name    = "_443._tcp"
          type    = "TXT"
          ttl     = 300
          records = ["3 1 1 ${local.tlsa_hash_kiraum}"]
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
            "protonmail-verification=cc3c2c9aebe9de240703d0be5df8c25c2adc5460",
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
  domain_name            = "kiraum.it"
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
