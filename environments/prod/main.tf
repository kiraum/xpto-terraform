terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0.0"
    }
  }
}

# Default provider configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
      Project     = var.project
      CostCenter  = var.cost_center
      # DataClassification = var.data_classification
    }
  }
}

# US East 1 provider configuration
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
      Project     = var.project
      CostCenter  = var.cost_center
      # DataClassification = var.data_classification
    }
  }
}

module "billing_report" {
  source = "../../modules/billing_report"

  lambda_function_name = "billing-report-lambda"
  sns_topic_name       = "root-account-topic"
  email_subscription   = "tfgoncalves@xpto.it"
  dynamodb_table_name  = "CostExplorerProcessedDates"
  ruler_name           = "billing-report-daily-schedule"
}

module "route53" {
  source = "../../modules/route53"

  hosted_zones = {
    "kiraum_it" = {
      domain_name = "kiraum.it"
      comment     = "kiraum.it hosted zone"
      records = [
        {
          name = ""
          type = "A"
          alias = {
            name                   = "dpop20p5u4112.cloudfront.net"
            zone_id                = "Z2FDTNDATAQYW2" # This is the hosted zone ID for CloudFront
            evaluate_target_health = false
          }
        },
        {
          name    = "www"
          type    = "CNAME"
          ttl     = 300
          records = ["dpop20p5u4112.cloudfront.net"]
        }
      ]
    }
  }
}

module "static_website" {
  source = "../../modules/static_website"

  bucket_name            = "xpto-static-website-bucket"
  domain_name            = "kiraum.it"
  cloudfront_price_class = "PriceClass_100"
  tags = {
    Environment = var.environment
    Project     = var.project
  }

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }
}
