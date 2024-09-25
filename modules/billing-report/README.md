## Billing Report Module

The `billing-report` module sets up an AWS Lambda function that generates daily AWS cost reports and sends them via SNS.

### Features

- Daily execution using EventBridge scheduler
- Generates cost reports using AWS Cost Explorer API
- Sends reports via SNS to a specified email address

### Lambda Function

The Lambda function is written in Python 3.12 and uses the following libraries:
- boto3
- json
- datetime

### Development

The module includes several development tools and configurations:

- `pyproject.toml`: Defines project metadata and development dependencies
- `requirements.txt`: Lists runtime dependencies for the Lambda function
- `.pre-commit-config.yaml`: Configures pre-commit hooks for code quality

### Usage

To use this module in your Terraform configuration:

```hcl
module "billing_report" {
  source              = "../../modules/billing-report"
  lambda_function_name = "billing-report-lambda"
  sns_topic_name       = "root-account-topic"
  email_subscription   = "tfgoncalves@xpto.it"
}
```
### Customization
You can customize the module by adjusting the variables defined in variables.tf, such as:
* lambda_function_name
* sns_topic_name
* email_subscription
* ruler_name

For more details on implementation, refer to the main.tf file in the billing-report module directory.