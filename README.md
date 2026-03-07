# placethedude

Node.js-powered placeholder image service for The Dude, deployed on AWS Lambda behind CloudFront.

## What changed

- The Go Lambda/API Gateway implementation has been replaced with a Node.js Lambda handler.
- API Gateway is removed in favor of a Lambda Function URL fronted by CloudFront.
- The static website lives in `apps/site/` and is deployed to S3 behind the same CloudFront distribution.
- The Lambda image service lives in `apps/image-service/`.
- Terraform in `infra/terraform/` manages the AWS infrastructure.

## URL structure

- Website: `/`
- Placeholder images: `/img/{width}/{height}`
- Optional future handler slot remains reserved: `/img/{handler}/{width}/{height}`

Examples:

- `/img/300/200`
- `/img/640/360`

The `/img` prefix is intentional so CloudFront can cleanly route static site traffic to S3 and image requests to Lambda.

## App configuration

The Lambda function uses environment variables instead of Secrets Manager for app config:

- `IMAGE_BUCKET`
- `IMAGE_COUNT`
- `IMAGE_KEY_PREFIX` (default: `thedude-`)
- `IMAGE_KEY_SUFFIX` (default: `.jpg`)
- `IMAGE_NUMBER_PADDING` (default: `2`)
- `JPEG_QUALITY` (default: `90`)
- `RESPONSE_CACHE_CONTROL` (default: `public, max-age=31536000, s-maxage=31536000`)

AWS credentials are not stored in app config. The Lambda function reads from S3 using its IAM role.

## Local commands

```bash
npm ci
npm test
```

To build a Lambda artifact locally after dependencies are installed:

```bash
npm run package
```

Note: package the Lambda on Linux for deployment so native `sharp` binaries match the Lambda runtime. The GitHub Actions workflow already does this.

## Repo layout

- `apps/site/` - static site assets synced to the website bucket
- `apps/image-service/` - Lambda handler, tests, and packaging script
- `infra/terraform/` - AWS infrastructure and DNS

## Terraform

Terraform lives in `infra/terraform/`.

Before using GitHub Actions, create an S3 bucket for Terraform remote state, enable bucket versioning, then set the repo variables used by `.github/workflows/deploy.yml`.

Terraform creates both the website bucket and the source image bucket. After the first apply, upload your placeholder source images into the image bucket named by `IMAGE_BUCKET_NAME`.

Required GitHub repository variables:

- `AWS_REGION`
- `AWS_ROLE_TO_ASSUME`
- `PROJECT_NAME`
- `ENVIRONMENT`
- `WEBSITE_BUCKET_NAME`
- `IMAGE_BUCKET_NAME`
- `IMAGE_COUNT`
- `TF_STATE_BUCKET`

Optional GitHub repository variables:

- `CLOUDFRONT_ALIASES_JSON` (example: `["placethedude.com","www.placethedude.com"]`)
- `ACM_CERTIFICATE_ARN`
- `ROUTE53_ZONE_ID`
