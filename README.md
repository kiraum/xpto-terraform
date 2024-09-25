# xpto-terraform

This repository contains Terraform configurations for managing AWS infrastructure for the XPTO project.

## Project Structure

- `environments/`: Contains environment-specific configurations
  - `prod/`: Production environment configuration
  - `tfstate/`: Terraform state management configuration
- `modules/`: Reusable Terraform modules
  - `billing-report/`: Module for generating AWS billing reports

## Prerequisites

- Terraform (version X.X or later)
- AWS CLI configured with appropriate credentials
- Python 3.12 or later (for the billing report Lambda function)

## Getting Started

1. Clone this repository:
```
git clone https://github.com/your-org/xpto-terraform.git cd xpto-terraform
```

2. Set up your AWS credentials:
```
source ./aws_auth.sh
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

The billing report module sets up a Lambda function that generates daily AWS cost reports and sends them via SNS.

To use this module, see the example in `environments/prod/main.tf`.

## Contributing

Please refer to the `.pre-commit-config.yaml` file for code style and linting requirements before submitting pull requests.

## License

GNU Affero General Public License v3.0