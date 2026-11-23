data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  prefix     = "${var.name_root}-${var.project}"

  # Route 53 and ACM normalize names: lowercase, without the trailing dot.
  record_name = trimsuffix(lower(var.domain), ".")

  project_tag_condition = {
    StringEquals = {
      "aws:ResourceTag/Project" = var.project
    }
  }

  # Write-only: pair it with monitoring/read, which the apply role also needs
  # for refresh and while it waits for the certificate.
  policy = {
    Version = "2012-10-17"
    Statement = [
      {
        # A request carries no resource ARN; the tag, the validation method and
        # the one domain name are the scope.
        Sid      = "RequestTheOffHoursCertificate"
        Effect   = "Allow"
        Action   = "acm:RequestCertificate"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Project" = var.project
            "acm:ValidationMethod"   = "DNS"
          }
          "ForAllValues:StringEquals" = {
            "acm:DomainNames" = [local.record_name]
          }
        }
      },
      {
        Sid    = "ManageTheOffHoursCertificate"
        Effect = "Allow"
        Action = [
          "acm:DeleteCertificate",
          "acm:AddTagsToCertificate",
          "acm:RemoveTagsFromCertificate",
        ]
        Resource  = "arn:aws:acm:us-east-1:${local.account_id}:certificate/*"
        Condition = local.project_tag_condition
      },
      {
        # Creation carries no resource ARN yet; the request tag is the scope.
        Sid    = "CreateTheOffHoursPage"
        Effect = "Allow"
        Action = [
          "cloudfront:CreateDistribution",
          "cloudfront:CreateFunction",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Project" = var.project
          }
        }
      },
      {
        Sid    = "ManageTheOffHoursDistribution"
        Effect = "Allow"
        Action = [
          "cloudfront:UpdateDistribution",
          "cloudfront:DeleteDistribution",
          "cloudfront:TagResource",
          "cloudfront:UntagResource",
        ]
        Resource  = "arn:aws:cloudfront::${local.account_id}:distribution/*"
        Condition = local.project_tag_condition
      },
      {
        # The node module names its function <name>-off-hours-page, with
        # name = <name_root>-<project>.
        Sid    = "ManageTheOffHoursFunction"
        Effect = "Allow"
        Action = [
          "cloudfront:UpdateFunction",
          "cloudfront:PublishFunction",
          "cloudfront:DeleteFunction",
          "cloudfront:TagResource",
          "cloudfront:UntagResource",
        ]
        Resource  = "arn:aws:cloudfront::${local.account_id}:function/${local.prefix}-off-hours-page"
        Condition = local.project_tag_condition
      },
      {
        # ACM's DNS validation record is a CNAME named _<token>.<domain>.
        Sid      = "ChangeTheValidationRecord"
        Effect   = "Allow"
        Action   = "route53:ChangeResourceRecordSets"
        Resource = "arn:aws:route53:::hostedzone/${var.zone_id}"
        Condition = {
          "ForAllValues:StringLike" = {
            "route53:ChangeResourceRecordSetsNormalizedRecordNames" = ["_*.${local.record_name}"]
            "route53:ChangeResourceRecordSetsRecordTypes"           = ["CNAME"]
          }
        }
      },
    ]
  }
}

resource "aws_iam_policy" "this" {
  name        = var.name
  description = "CI policy monitoring/off-hours-page: manage the monitoring node's off-hours page (its certificate, distribution and function) and the certificate's validation record"
  policy      = jsonencode(local.policy)

  tags = {
    Component = "ci"
  }
}
