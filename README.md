# static-site

Terraform module that serves a static website from a private S3 bucket
through CloudFront.

The module suits sites built elsewhere (for example a Jekyll build in CI)
and uploaded as files. It pairs with the `terraform-aws-clientlog-edge`
module, which captures the distribution's access logs.

## What it creates

- A private S3 bucket with public access blocked and AES256 encryption
- A CloudFront origin access control
- A bucket policy that lets one distribution, and no other principal, read
  objects
- A CloudFront distribution with managed cache and security-header policies,
  HTTP redirected to HTTPS, and compression
- Optional Route 53 alias records (A and AAAA) for each alias

## Requirements

- Terraform 1.3 or later
- AWS provider 5.0 or later
- An ACM certificate in us-east-1 that covers every alias. The module does
  not create it.
- A Route 53 hosted zone, if `manage_dns` is true

## Usage

```hcl
module "site" {
  source = "github.com/bayinfosys/terraform-aws-clientlog-edge//modules/static-site?ref=v1.0.1"

  bucket_name     = "example-prod-www"
  aliases         = ["example.com"]
  certificate_arn = module.acm_us_east.acm_certificate_arn

  manage_dns = true
  zone_id    = aws_route53_zone.primary.zone_id

  tags = { project = "example" }
}
```

The certificate must be created with a provider configured for us-east-1.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| bucket_name | string | required | Name of the S3 bucket |
| aliases | list(string) | required | Domain names served by the distribution |
| certificate_arn | string | required | ACM certificate ARN in us-east-1 covering the aliases |
| comment | string | "" | Distribution comment |
| origin_id | string | "s3-site" | Origin identifier |
| price_class | string | "PriceClass_100" | CloudFront price class. PriceClass_100 excludes Asia |
| default_root_object | string | "index.html" | Object served for the root path |
| error_page | string | "/404.html" | Object served with status 404 for missing keys |
| minimum_protocol_version | string | "TLSv1.2_2021" | Minimum TLS version for viewers |
| cache_policy_name | string | "Managed-CachingOptimized" | Name of the CloudFront cache policy |
| response_headers_policy_name | string | "Managed-SecurityHeadersPolicy" | Name of the response headers policy |
| manage_dns | bool | false | Create alias records in zone_id |
| zone_id | string | null | Route 53 hosted zone ID, required when manage_dns is true |
| tags | map(string) | {} | Tags for the bucket and distribution |

## Outputs

| Name | Description |
|------|-------------|
| bucket | Name of the S3 bucket |
| bucket_arn | ARN of the S3 bucket |
| distribution_id | CloudFront distribution ID |
| distribution_arn | CloudFront distribution ARN |
| distribution_domain | The distribution's cloudfront.net domain |

Test a new site on `distribution_domain` before pointing DNS at it.

## Deploying content

The managed cache policy takes the time to live from each object's
`Cache-Control` header, so the upload sets it. A two-pass sync gives pages a
short lifetime and assets a long one:

```bash
BUCKET=$(terraform output -raw site_bucket)

aws s3 sync _site "s3://$BUCKET" \
  --exclude "*.html" --exclude "*.xml" --exclude "*.txt" \
  --cache-control "public, max-age=86400" --delete

aws s3 sync _site "s3://$BUCKET" \
  --exclude "*" --include "*.html" --include "*.xml" --include "*.txt" \
  --cache-control "public, max-age=300" --delete

aws cloudfront create-invalidation \
  --distribution-id "$(terraform output -raw distribution_id)" --paths "/*"
```

## Behaviour to know about

- **Default document.** `default_root_object` applies to the root path only.
  A request for `/docs/` does not serve `/docs/index.html`. Use direct file
  permalinks (`/docs/page.html`), which Jekyll produces with
  `permalink: /:path/:basename:output_ext` or an `.html` permalink.
- **Missing pages.** S3 returns 403 for a key that does not exist. The
  distribution maps both 403 and 404 to the error page with a 404 status, so
  search engines do not record soft 404 pages.
- **Redirects.** Viewer requests over HTTP receive a redirect to HTTPS.
  Redirects between `www` and the apex domain are not included.
- **Access.** Only the distribution created by this module can read the
  bucket. Objects have no public URL.
- **Single origin.** The module serves one bucket. It adds no functions, WAF
  or additional behaviours.

## Adopting an existing stack

Resources moved into the module change their Terraform address. Add a
`moved` block for each, or the plan destroys and recreates them:

```hcl
moved {
  from = aws_s3_bucket.site
  to   = module.site.aws_s3_bucket.site
}

moved {
  from = aws_cloudfront_distribution.site
  to   = module.site.aws_cloudfront_distribution.site
}
```

Repeat for every resource the module creates. A `moved` block cannot contain
an expression, so alias record keys are written as literals, for example
`module.site.aws_route53_record.alias_a["example.com"]`. The plan for a
correct move reports no additions, changes or destroys for these resources.

## Access logs

The distribution's ARN is an output, so the logging module attaches to it:

```hcl
module "edge_logging" {
  source = "github.com/bayinfosys/terraform-aws-clientlog-edge?ref=v1.0.1"

  providers = {
    aws.us_east = aws.us_east
  }

  name              = "example-prod"
  distribution_arns = { site = module.site.distribution_arn }
}
```

## Licence

MIT. See LICENSE.
