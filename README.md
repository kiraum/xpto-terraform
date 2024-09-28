# xpto-terraform

This repository contains Terraform configurations for managing AWS infrastructure for the XPTO project. The main goal is to maintain a secure infrastructure while keeping costs low by maximizing the use of the AWS Free Tier (https://aws.amazon.com/free/).

## Project Structure

- `environments/`: Contains environment-specific configurations
  - `prod/`: Production environment configuration
  - `tfstate/`: Terraform state management configuration
- `modules/`: Reusable Terraform modules
  - `billing_report/`: Module for generating AWS billing reports
  - `static_website/`: Module for setting up a static website with CloudFront
  - `route53/`: Module for managing Route53 DNS configurations

## Prerequisites

- Terraform (version 1.0.0 or later)
- AWS CLI configured with appropriate credentials
- Python 3.12 or later (for the billing report Lambda function)

## Getting Started

1. Clone this repository:
```
git clone https://github.com/your-org/xpto-terraform.git cd xpto-terraform
```

2. Set up your AWS credentials:
```
source ./scripts/aws_auth.sh
```

3. Initialize Terraform:
```
terraform init
```

4. Plan the changes:
```
terform plan
```

5. Apply the Terraform configuration:
```
terraform apply
```


## Modules

### Billing Report

The billing report module sets up a Lambda function that generates daily AWS cost reports and sends them via SNS. It includes:
- Lambda function for cost analysis (located at `modules/billing_report/lambda_function.py`)
- CloudWatch event rule for daily triggering
- SNS topic for notifications
- IAM roles and policies
- DynamoDB table for storing report data

### Route53

The Route53 module manages DNS configurations for the project. It includes:
- Creation and management of Route53 hosted zones
- DNS record management for various AWS resources
- Integration with other modules for domain name resolution

### Static Website

The static website module creates an S3 bucket for hosting static content and sets up CloudFront distribution. It includes:
- S3 bucket with appropriate policies
- CloudFront distribution with custom domain and SSL
- Lambda@Edge function for security headers
- Route53 DNS configuration
- ACM certificate for HTTPS
- Budget alerts for CloudFront usage

## Cost Optimization

This project is designed to leverage the AWS Free Tier as much as possible:
- S3 buckets use the standard tier with minimal operations
- Lambda functions are configured to stay within free tier limits
- CloudFront distribution is optimized for low-cost usage
- DynamoDB tables use on-demand capacity to minimize costs
- CloudWatch logs have a 7-day retention period to reduce storage costs

## Contributing

Please refer to the `.pre-commit-config.yaml` file for code style and linting requirements before submitting pull requests.

## License

GNU Affero General Public License v3.0
