provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment        = var.environment
      ManagedBy          = "terraform"
      Project            = var.project
      CostCenter         = var.cost_center
      DataClassification = var.data_classification
    }
  }
}

module "billing_report" {
  source = "../../modules/billing-report"

  lambda_function_name = "billing-report-lambda"
  sns_topic_name       = "root-account-topic"
  email_subscription   = "tfgoncalves@xpto.it"
}

module "route53" {
  source = "../../modules/route53"

  hosted_zones = {
    "kiraum_it" = {
      domain_name = "kiraum.it"
      comment     = "kiraum.it hosted zone"
      records = [
        {
          name    = "www"
          type    = "CNAME"
          ttl     = 300
          records = ["example.org"]
        }
      ]
    }
  }

}

