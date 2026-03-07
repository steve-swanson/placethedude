variable "aws_region" {
  description = "AWS region for regional resources."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used in resource naming and tags."
  type        = string
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "prod"
}

variable "website_bucket_name" {
  description = "S3 bucket name for the static website assets."
  type        = string
}

variable "image_bucket_name" {
  description = "S3 bucket containing source placeholder images."
  type        = string
}

variable "image_count" {
  description = "Number of source images available in the image bucket."
  type        = number
}

variable "image_key_prefix" {
  description = "Prefix for image object keys."
  type        = string
  default     = "thedude-"
}

variable "image_key_suffix" {
  description = "Suffix for image object keys."
  type        = string
  default     = ".jpg"
}

variable "image_number_padding" {
  description = "Zero padding width used when generating image keys."
  type        = number
  default     = 2
}

variable "jpeg_quality" {
  description = "JPEG quality used by sharp when writing output images."
  type        = number
  default     = 90
}

variable "response_cache_control" {
  description = "Cache-Control header sent by the Lambda image response."
  type        = string
  default     = "public, max-age=31536000, s-maxage=31536000"
}

variable "lambda_package_path" {
  description = "Path to the Lambda zip artifact generated before terraform apply."
  type        = string
  default     = "../../lambda.zip"
}

variable "cloudfront_aliases_json" {
  description = "JSON-encoded list of CloudFront aliases. Leave as [] to use the default CloudFront domain."
  type        = string
  default     = "[]"
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN in us-east-1 for CloudFront aliases. Leave empty to use the default CloudFront certificate."
  type        = string
  default     = ""
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for alias records. Leave empty to skip DNS record creation."
  type        = string
  default     = ""
}
