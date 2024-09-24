variable "aws_region" {
  description = "The AWS region to create resources in"
  type        = string
}

variable "state_bucket_name" {
  description = "The name of the S3 bucket to store Terraform state"
  type        = string
}

variable "dynamodb_table_name" {
  description = "The name of the DynamoDB table for Terraform state locking"
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

variable "data_classification" {
  description = "Data classification for tagging"
  type        = string
}