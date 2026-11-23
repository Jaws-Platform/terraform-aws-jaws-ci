mock_provider "aws" {
  override_during = plan

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
}

variables {
  name      = "acme-monitoring-ci-apply-monitoring-off-hours-page"
  name_root = "acme"
  project   = "monitoring"
  zone_id   = "Z0123456789ABCDEFGHIJ"
  domain    = "grafana.example.com"
}

run "off_hours_page_grants_exactly_these_statements" {
  command = plan

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "RequestTheOffHoursCertificate"])) == jsonencode({
      Sid      = "RequestTheOffHoursCertificate"
      Effect   = "Allow"
      Action   = "acm:RequestCertificate"
      Resource = "*"
      Condition = {
        StringEquals = {
          "aws:RequestTag/Project" = "monitoring"
          "acm:ValidationMethod"   = "DNS"
        }
        "ForAllValues:StringEquals" = {
          "acm:DomainNames" = ["grafana.example.com"]
        }
      }
    })
    error_message = "a certificate for the domain only, DNS-validated, tagged with the project"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "ManageTheOffHoursCertificate"])) == jsonencode({
      Sid    = "ManageTheOffHoursCertificate"
      Effect = "Allow"
      Action = [
        "acm:DeleteCertificate",
        "acm:AddTagsToCertificate",
        "acm:RemoveTagsFromCertificate",
      ]
      Resource = "arn:aws:acm:us-east-1:123456789012:certificate/*"
      Condition = {
        StringEquals = {
          "aws:ResourceTag/Project" = "monitoring"
        }
      }
    })
    error_message = "the project's certificates in us-east-1"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "CreateTheOffHoursPage"])) == jsonencode({
      Sid    = "CreateTheOffHoursPage"
      Effect = "Allow"
      Action = [
        "cloudfront:CreateDistribution",
        "cloudfront:CreateFunction",
      ]
      Resource = "*"
      Condition = {
        StringEquals = {
          "aws:RequestTag/Project" = "monitoring"
        }
      }
    })
    error_message = "creation is tagged with the project"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "ManageTheOffHoursDistribution"])) == jsonencode({
      Sid    = "ManageTheOffHoursDistribution"
      Effect = "Allow"
      Action = [
        "cloudfront:UpdateDistribution",
        "cloudfront:DeleteDistribution",
        "cloudfront:TagResource",
        "cloudfront:UntagResource",
      ]
      Resource = "arn:aws:cloudfront::123456789012:distribution/*"
      Condition = {
        StringEquals = {
          "aws:ResourceTag/Project" = "monitoring"
        }
      }
    })
    error_message = "the project's distributions"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "ManageTheOffHoursFunction"])) == jsonencode({
      Sid    = "ManageTheOffHoursFunction"
      Effect = "Allow"
      Action = [
        "cloudfront:UpdateFunction",
        "cloudfront:PublishFunction",
        "cloudfront:DeleteFunction",
        "cloudfront:TagResource",
        "cloudfront:UntagResource",
      ]
      Resource = "arn:aws:cloudfront::123456789012:function/acme-monitoring-off-hours-page"
      Condition = {
        StringEquals = {
          "aws:ResourceTag/Project" = "monitoring"
        }
      }
    })
    error_message = "the one function, named <name_root>-<project>-off-hours-page"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "ChangeTheValidationRecord"])) == jsonencode({
      Sid      = "ChangeTheValidationRecord"
      Effect   = "Allow"
      Action   = "route53:ChangeResourceRecordSets"
      Resource = "arn:aws:route53:::hostedzone/Z0123456789ABCDEFGHIJ"
      Condition = {
        "ForAllValues:StringLike" = {
          "route53:ChangeResourceRecordSetsNormalizedRecordNames" = ["_*.grafana.example.com"]
          "route53:ChangeResourceRecordSetsRecordTypes"           = ["CNAME"]
        }
      }
    })
    error_message = "only a CNAME named _<token>.<domain>, in the one zone"
  }
}

run "off_hours_page_grants_nothing_else" {
  command = plan

  assert {
    condition = jsonencode(sort([for s in jsondecode(aws_iam_policy.this.policy).Statement : s.Sid])) == jsonencode(sort([
      "RequestTheOffHoursCertificate",
      "ManageTheOffHoursCertificate",
      "CreateTheOffHoursPage",
      "ManageTheOffHoursDistribution",
      "ManageTheOffHoursFunction",
      "ChangeTheValidationRecord",
    ]))
    error_message = "monitoring/off-hours-page is exactly these statements"
  }

  assert {
    condition     = alltrue([for s in jsondecode(aws_iam_policy.this.policy).Statement : can(s.Condition)])
    error_message = "every statement is conditioned"
  }

  assert {
    condition     = !anytrue([for a in flatten([for s in jsondecode(aws_iam_policy.this.policy).Statement : tolist(flatten([s.Action]))]) : strcontains(a, "*")])
    error_message = "no wildcard actions"
  }

  assert {
    condition = alltrue([
      for a in flatten([for s in jsondecode(aws_iam_policy.this.policy).Statement : tolist(flatten([s.Action]))]) :
      !can(regex("^[a-z0-9]+:(Describe|Get|List)", a))
    ])
    error_message = "a write policy grants no reads; monitoring/read has them"
  }
}

run "off_hours_page_normalizes_the_domain" {
  command = plan

  variables {
    domain = "Grafana.Example.com."
  }

  assert {
    condition     = one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s.Condition["ForAllValues:StringEquals"]["acm:DomainNames"] if s.Sid == "RequestTheOffHoursCertificate"]) == ["grafana.example.com"]
    error_message = "the certificate's domain has no trailing dot"
  }

  assert {
    condition     = one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s.Condition["ForAllValues:StringLike"]["route53:ChangeResourceRecordSetsNormalizedRecordNames"] if s.Sid == "ChangeTheValidationRecord"]) == ["_*.grafana.example.com"]
    error_message = "Route 53 normalizes names without the trailing dot"
  }
}

run "off_hours_page_rejects_a_wildcard_domain" {
  command = plan

  variables {
    domain = "*.example.com"
  }

  expect_failures = [var.domain]
}

run "rejects_a_malformed_zone" {
  command = plan

  variables {
    zone_id = "zone"
  }

  expect_failures = [var.zone_id]
}
