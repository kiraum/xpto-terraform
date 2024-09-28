## Billing Report Module

The `billing-report` module sets up an AWS Lambda function that generates daily, weekly, monthly, and yearly AWS cost reports and sends them via SNS.

As a primarily free tier user, this Lambda function serves as an additional safeguard against unexpected costs, complementing the existing alerts set up in Cost Explorer.

### Features

- Flexible execution using EventBridge scheduler
- Generates cost reports using AWS Cost Explorer API for various time periods
- Sends detailed reports via SNS when costs exceed configurable thresholds
- Uses DynamoDB to prevent duplicate processing of time periods


### Lambda Function

The Lambda function is written in Python 3.12 and uses the following libraries:
- boto3
- json
- datetime
- os

### Development

The module includes several development tools and configurations:

- `pyproject.toml`: Defines project metadata and development dependencies
- `requirements.txt`: Lists runtime dependencies for the Lambda function
- `.pre-commit-config.yaml`: Configures pre-commit hooks for code quality

### Usage

To use this module in your Terraform configuration:

```hcl
module "billing_report" {
  source               = "../../modules/billing_report"
  lambda_function_name = "billing-report-lambda"
  sns_topic_name       = "billing-report-topic"
  email_subscription   = "tfgoncalves@xpto.it"
  dynamodb_table_name  = "CostExplorerProcessedDates"
  ruler_name           = "billing-report-daily-schedule"
}

```
### Customization
You can customize the module by adjusting the variables defined in variables.tf, such as:

* lambda_function_name
* sns_topic_name
* email_subscription
* ruler_name
* dynamodb_table_name

The Lambda function also uses environment variables for cost thresholds, which can be customized:

* DAILY_COST_THRESHOLD
* WEEKLY_COST_THRESHOLD
* MONTHLY_COST_THRESHOLD
* YEARLY_COST_THRESHOLD

For more details on implementation, refer to the main.tf and lambda_function.py files in the billing-report module directory.
