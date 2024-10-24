variable "container_name" {
  type        = string
  description = "Name of the Lightsail container service"
}

variable "container_image" {
  type        = string
  description = "Docker image to use for the container"
}

variable "availability_zone" {
  type        = string
  description = "Availability zone for the Lightsail instance"
}

variable "bundle_id" {
  type        = string
  description = "Lightsail bundle ID (instance size)"
}

variable "custom_domain_name" {
  type        = list(string)
  description = "List of domain names for the Lightsail certificate"
}

variable "subject_alternative_names" {
  type        = list(string)
  description = "List of additional domain names for the certificate"
  default     = []
}

variable "sns_topic_subscribers" {
  description = "List of email addresses to subscribe to the SNS topic"
  type        = list(string)
  default     = []
}

variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD for Lightsail resources"
  type        = string
  default     = "10"
}
