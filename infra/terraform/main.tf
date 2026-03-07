data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_origin_request_policy" "s3_cors" {
  name = "Managed-CORS-S3Origin"
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
  cloudfront_aliases     = try(jsondecode(var.cloudfront_aliases_json), [])
  use_custom_certificate = var.acm_certificate_arn != ""
  use_route53_alias      = var.route53_zone_id != "" && length(local.cloudfront_aliases) > 0
}

resource "aws_s3_bucket" "website" {
  bucket = var.website_bucket_name
  tags   = local.tags
}

resource "aws_s3_bucket" "images" {
  bucket = var.image_bucket_name
  tags   = local.tags
}

resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "images" {
  bucket = aws_s3_bucket.images.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "images" {
  bucket = aws_s3_bucket.images.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "website" {
  bucket = aws_s3_bucket.website.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_ownership_controls" "images" {
  bucket = aws_s3_bucket.images.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "images" {
  bucket = aws_s3_bucket.images.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "lambda" {
  name = "${local.name_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_images" {
  name = "${local.name_prefix}-lambda-images"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject"
        ],
        Resource = "${aws_s3_bucket.images.arn}/*"
      }
    ]
  })
}

resource "aws_lambda_function" "images" {
  function_name    = "${local.name_prefix}-images"
  role             = aws_iam_role.lambda.arn
  runtime          = "nodejs20.x"
  handler          = "src/handler.handler"
  filename         = var.lambda_package_path
  source_code_hash = filebase64sha256(var.lambda_package_path)
  timeout          = 15
  memory_size      = 1024
  architectures    = ["x86_64"]

  environment {
    variables = {
      IMAGE_BUCKET           = aws_s3_bucket.images.bucket
      IMAGE_COUNT            = tostring(var.image_count)
      IMAGE_KEY_PREFIX       = var.image_key_prefix
      IMAGE_KEY_SUFFIX       = var.image_key_suffix
      IMAGE_NUMBER_PADDING   = tostring(var.image_number_padding)
      JPEG_QUALITY           = tostring(var.jpeg_quality)
      RESPONSE_CACHE_CONTROL = var.response_cache_control
    }
  }

  tags = local.tags
}

resource "aws_lambda_function_url" "images" {
  function_name      = aws_lambda_function.images.function_name
  authorization_type = "AWS_IAM"
}

resource "aws_cloudfront_origin_access_control" "website" {
  name                              = "${local.name_prefix}-website-oac"
  description                       = "CloudFront access control for website S3 origin"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_origin_access_control" "lambda" {
  name                              = "${local.name_prefix}-lambda-oac"
  description                       = "CloudFront access control for Lambda Function URL origin"
  origin_access_control_origin_type = "lambda"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project_name} ${var.environment}"
  default_root_object = "index.html"
  aliases             = local.cloudfront_aliases
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id                = "website-s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id
  }

  origin {
    domain_name              = trimsuffix(trimprefix(aws_lambda_function_url.images.function_url, "https://"), "/")
    origin_id                = "images-lambda-url"
    origin_access_control_id = aws_cloudfront_origin_access_control.lambda.id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id         = "website-s3"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD", "OPTIONS"]
    cached_methods           = ["GET", "HEAD", "OPTIONS"]
    compress                 = true
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.s3_cors.id
  }

  ordered_cache_behavior {
    path_pattern           = "img/*"
    target_origin_id       = "images-lambda-url"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    compress               = true
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = ! local.use_custom_certificate
    acm_certificate_arn            = local.use_custom_certificate ? var.acm_certificate_arn : null
    ssl_support_method             = local.use_custom_certificate ? "sni-only" : null
    minimum_protocol_version       = local.use_custom_certificate ? "TLSv1.2_2021" : "TLSv1"
  }

  tags = local.tags
}

data "aws_iam_policy_document" "website_bucket" {
  statement {
    sid = "AllowCloudFrontRead"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.website.arn}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = data.aws_iam_policy_document.website_bucket.json
}

resource "aws_lambda_permission" "cloudfront_function_url" {
  statement_id           = "AllowCloudFrontInvokeFunctionUrl"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.images.function_name
  principal              = "cloudfront.amazonaws.com"
  source_arn             = aws_cloudfront_distribution.site.arn
  function_url_auth_type = "AWS_IAM"
}

resource "aws_route53_record" "aliases" {
  count   = local.use_route53_alias ? length(local.cloudfront_aliases) : 0
  zone_id = var.route53_zone_id
  name    = local.cloudfront_aliases[count.index]
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "aliases_ipv6" {
  count   = local.use_route53_alias ? length(local.cloudfront_aliases) : 0
  zone_id = var.route53_zone_id
  name    = local.cloudfront_aliases[count.index]
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}
