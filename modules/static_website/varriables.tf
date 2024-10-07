variable "domain_names" {
  type        = list(string)
  description = "The domain names for the static website"
}

variable "bucket_name" {
  type        = string
  description = "The name of the S3 bucket to create"
}

variable "cloudfront_price_class" {
  type        = string
  description = "The price class for the CloudFront distribution"
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to add to all resources"
  default     = {}
}

variable "mime_types" {
  type        = map(string)
  description = "Map of file extensions to MIME types"
  default = {
    html = "text/html"
    css  = "text/css"
    js   = "application/javascript"
    png  = "image/png"
    jpg  = "image/jpeg"
    jpeg = "image/jpeg"
    gif  = "image/gif"
    ico  = "image/vnd.microsoft.icon"
    txt  = "text/plain"
    svg  = "image/svg+xml"
  }
}
