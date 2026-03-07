output "website_bucket_name" {
  value       = aws_s3_bucket.website.bucket
  description = "S3 bucket name that receives static website assets."
}

output "image_bucket_name" {
  value       = aws_s3_bucket.images.bucket
  description = "S3 bucket name that stores the source placeholder images."
}

output "cloudfront_distribution_id" {
  value       = aws_cloudfront_distribution.site.id
  description = "CloudFront distribution ID used by the deploy workflow for invalidations."
}

output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.site.domain_name
  description = "CloudFront domain name for the deployed site."
}

output "lambda_function_url" {
  value       = aws_lambda_function_url.images.function_url
  description = "Lambda Function URL used as the CloudFront image origin."
}
