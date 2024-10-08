variable "aws_region" {
  description = "The AWS region to create resources in"
  type        = string
}
variable "environment" {
  description = "Environment name for tagging"
  type        = string
}

variable "project" {
  description = "Project name for tagging"
  type        = string
}

variable "cost_center" {
  description = "Cost center for tagging"
  type        = string
}

#variable "data_classification" {
#  description = "Data classification for tagging"
#  type        = string
#}

variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications"
  type        = string
  default     = ""
}

output "ds_records" {
  value       = module.route53.ds_records
  description = "The DS records for DNSSEC-enabled domains"
}
