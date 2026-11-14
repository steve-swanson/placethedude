# placethedude

[![Deploy main](https://github.com/steve-swanson/placethedude/actions/workflows/deploy.yml/badge.svg?branch=main)](https://github.com/steve-swanson/placethedude/actions/workflows/deploy.yml?query=branch%3Amain)

Placeholder images of The Dude from *The Big Lebowski*, sized for your website or mockup.

```html
<img src="https://placethedude.com/img/640/360" width="640" height="360" alt="The Dude">
```

Requests to `/img/{width}/{height}` select a source image from S3, crop it to fill the requested dimensions, and return a JPEG. Responses are cached by CloudFront and browsers, so repeated requests may show the same image.

The static website is served from S3. A Node.js Lambda function uses `sharp` to generate images, and CloudFront routes requests to both. Terraform manages the AWS infrastructure.

## Getting started

Use Node.js 20 or later. The deployment workflow and Lambda runtime currently use Node.js 20.

```sh
git clone https://github.com/steve-swanson/placethedude.git
cd placethedude
npm ci
npm test
```

Tests run locally without AWS credentials. There is no bundled local HTTP server; the image handler runs on Lambda. Calling the handler locally requires the configuration below and AWS credentials with read access to the source-image bucket.

| Path | Contents |
| --- | --- |
| `apps/site/` | Static HTML, CSS, and website assets |
| `apps/image-service/src/handler.js` | Image request handler |
| `apps/image-service/tests/` | Request parsing and image-key tests |
| `infra/terraform/` | AWS infrastructure and deployment settings |
| `.github/workflows/deploy.yml` | Staging and production deployment workflow |

## Image configuration

Terraform sets these environment variables on the Lambda function. For local calls, set them in your shell or Node.js process; the app does not load a `.env` file.

| Variable | Purpose | Default |
| --- | --- | --- |
| `IMAGE_BUCKET` | S3 bucket containing source images | Required |
| `IMAGE_COUNT` | Number of source images, numbered consecutively from 1 | `10`; explicitly required by Terraform |
| `IMAGE_KEY_PREFIX` | Object-key prefix | `thedude-` |
| `IMAGE_KEY_SUFFIX` | Object-key suffix | `.jpg` |
| `IMAGE_NUMBER_PADDING` | Minimum number of digits in an image number | `2` |
| `JPEG_QUALITY` | Output JPEG quality | `90` |
| `RESPONSE_CACHE_CONTROL` | Response cache policy | `public, max-age=31536000, s-maxage=31536000` |

With the defaults and an image count of 10, upload `thedude-01.jpg` through `thedude-10.jpg` to the root of the source-image bucket. Every number must have a corresponding object, since the handler selects one at random. Source images are uploaded separately from the application deployment.

On AWS, the function accesses S3 through its IAM role. AWS access keys are not part of the application configuration.

## Deployment

Pushes to `develop` deploy through the GitHub environment `stg`; pushes to `main` deploy through `prod`. The workflow installs dependencies, runs tests, packages Lambda, applies Terraform, uploads the website, and invalidates the website cache.

Before the first deployment:

1. Create an S3 bucket for Terraform state and enable versioning. This bucket is separate from the website and source-image buckets that Terraform creates.
2. Configure an AWS IAM role that GitHub Actions can assume through OIDC, with permission to manage the infrastructure, deploy website assets, and access Terraform state. Its trust policy must allow the appropriate GitHub environments.
3. Configure the following GitHub Actions variables, using environment-level values for settings that differ between `stg` and `prod`.

| Variable | Value |
| --- | --- |
| `AWS_REGION` | AWS region; use `us-east-1` with the current Terraform defaults |
| `AWS_ROLE_TO_ASSUME` | ARN of the deployment IAM role |
| `PROJECT_NAME` | Resource-name prefix, such as `placethedude` |
| `ENVIRONMENT` | Environment name, such as `stg` or `prod` |
| `WEBSITE_BUCKET_NAME` | Globally unique bucket name for the website |
| `IMAGE_BUCKET_NAME` | Globally unique bucket name for source images |
| `IMAGE_COUNT` | Number of source images you will upload |
| `TF_STATE_BUCKET` | Existing Terraform-state bucket name |

Use distinct website and image buckets for each environment, and distinct `ENVIRONMENT` values to keep their Terraform state separate.

Optional variables for a custom domain:

| Variable | Value |
| --- | --- |
| `CLOUDFRONT_ALIASES_JSON` | JSON array, for example `["placethedude.com","www.placethedude.com"]` |
| `ACM_CERTIFICATE_ARN` | Certificate covering those domains, issued in `us-east-1` |
| `ROUTE53_ZONE_ID` | Hosted-zone ID if Terraform should create DNS alias records |

Without custom-domain settings, use the generated CloudFront domain. Terraform outputs include that domain, the bucket names, and the distribution ID. See [the example Terraform settings](infra/terraform/terraform.tfvars.example) and [all Terraform variables](infra/terraform/variables.tf) for additional options.

The workflow's `AWS_REGION` does not set Terraform's `aws_region` variable. To deploy regional resources outside `us-east-1`, also pass `TF_VAR_aws_region` in the workflow.

After the first deployment, upload the numbered source images to `IMAGE_BUCKET_NAME`, then request `/img/640/360` on the deployed domain to check image generation.

To build `lambda.zip` manually:

```sh
npm ci
npm run package
```

Build deployment packages on Linux x86-64 so the native `sharp` dependencies match Lambda. The GitHub Actions workflow handles this automatically. Manual infrastructure deployment also requires Terraform 1.13 or later, AWS credentials, and S3 backend configuration.
