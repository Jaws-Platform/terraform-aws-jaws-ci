data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region
  prefix     = "${var.name_root}-${var.project}"

  config_bucket = "arn:aws:s3:::${local.prefix}-config-${local.account_id}"

  # Route 53 normalizes record names in the condition key: lowercase, without
  # the trailing dot.
  record_name = var.domain == null ? null : trimsuffix(lower(var.domain), ".")

  # With a zone and a domain only: the node's record is optional.
  record_statements = [
    for s in [
      {
        # Terraform creates the record and deletes it; the node upserts its own
        # address there at every boot, with its own role.
        Sid      = "ChangeTheNodeRecord"
        Effect   = "Allow"
        Action   = "route53:ChangeResourceRecordSets"
        Resource = "arn:aws:route53:::hostedzone/${coalesce(var.zone_id, "none")}"
        Condition = {
          "ForAllValues:StringEquals" = {
            "route53:ChangeResourceRecordSetsNormalizedRecordNames" = [coalesce(local.record_name, "none")]
          }
        }
      },
    ] : s if var.zone_id != null && var.domain != null
  ]

  # Write-only: pair it with monitoring/read, which the apply role also needs
  # for refresh.
  policy = {
    Version = "2012-10-17"
    Statement = concat([
      {
        # The bucket and each configuration resource the node module gives it.
        Sid    = "ManageTheConfigBucket"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:PutBucketTagging",
          "s3:PutBucketOwnershipControls",
          "s3:PutBucketPublicAccessBlock",
          "s3:PutBucketVersioning",
          "s3:PutEncryptionConfiguration",
          "s3:PutLifecycleConfiguration",
        ]
        Resource = local.config_bucket
      },
      {
        # The config bundles. A bundle is named by its content, so every
        # change replaces one; in the versioned bucket the provider deletes
        # every version of the old key (DeleteObjectVersion).
        Sid    = "WriteTheConfigObjects"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectTagging",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",
        ]
        Resource = "${local.config_bucket}/*"
      },
      {
        # The node's parameters (config-bundle, status, running-config) under
        # /<prefix>/node/. The owner's secrets are not under /<prefix>/.
        Sid    = "ManageTheParameters"
        Effect = "Allow"
        Action = [
          "ssm:PutParameter",
          "ssm:DeleteParameter",
          "ssm:AddTagsToResource",
          "ssm:RemoveTagsFromResource",
        ]
        Resource = "arn:aws:ssm:${local.region}:${local.account_id}:parameter/${local.prefix}/*"
      },
    ], local.record_statements)
  }
}

resource "aws_iam_policy" "this" {
  name        = var.name
  description = "CI policy monitoring/config: manage the monitoring node's config bucket and bundles, its parameters and its DNS record"
  policy      = jsonencode(local.policy)

  tags = {
    Component = "ci"
  }
}
