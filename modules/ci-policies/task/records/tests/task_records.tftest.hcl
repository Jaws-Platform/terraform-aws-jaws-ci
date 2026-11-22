mock_provider "aws" {
  override_during = plan
}

variables {
  name   = "acme-technologies-rusty-chess-ci-task-task-records"
  bucket = "acme-technologies-billing-123456789012"
  prefix = "raw/provider=acme/source=task-runs/project=rusty-chess"
}

run "puts_records_only" {
  command = plan

  assert {
    condition = jsondecode(aws_iam_policy.this.policy).Statement == [
      {
        Sid      = "PutTaskRecords"
        Effect   = "Allow"
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::acme-technologies-billing-123456789012/raw/provider=acme/source=task-runs/project=rusty-chess/*"
      },
    ]
    error_message = "task/records must only put objects under the one prefix of the one bucket"
  }

  assert {
    condition     = aws_iam_policy.this.name == var.name && aws_iam_policy.this.tags == tomap({ Component = "ci" })
    error_message = "the policy must be named var.name and tagged Component = ci"
  }
}

# The writer puts each record once, with If-None-Match: *. A conditional put
# needs s3:PutObject and nothing more, so the policy reads, lists and deletes
# nothing, not even the records it wrote.
run "grants_nothing_else" {
  command = plan

  assert {
    condition     = length(jsondecode(aws_iam_policy.this.policy).Statement) == 1
    error_message = "task/records has exactly one statement"
  }

  assert {
    condition     = jsonencode(distinct(flatten([for s in jsondecode(aws_iam_policy.this.policy).Statement : tolist(flatten([s.Action]))]))) == jsonencode(["s3:PutObject"])
    error_message = "s3:PutObject is the only action: no get, list or delete"
  }

  assert {
    condition     = !anytrue([for s in jsondecode(aws_iam_policy.this.policy).Statement : s.Effect != "Allow" || can(s.NotAction) || can(s.NotResource) || anytrue([for r in flatten([s.Resource]) : !endswith(r, "/project=rusty-chess/*")])])
    error_message = "the only resource is the objects under the prefix: no bucket ARN, no wildcard, no NotAction or NotResource"
  }
}

run "takes_a_one_segment_prefix" {
  command = plan

  variables {
    prefix = "records"
  }

  assert {
    condition     = one(jsondecode(aws_iam_policy.this.policy).Statement).Resource == "arn:aws:s3:::acme-technologies-billing-123456789012/records/*"
    error_message = "a prefix without slashes covers the objects under <prefix>/"
  }
}

# `description` forces replacement of the policy, which would detach it from
# every role mid-apply. It is frozen; change the README instead.
run "description_is_frozen" {
  command = plan

  assert {
    condition     = aws_iam_policy.this.description == "CI policy task/records: write task-run records under one prefix of one bucket"
    error_message = "the policy description must never change: it forces replacement"
  }
}

run "rejects_a_bucket_arn" {
  command = plan

  variables {
    bucket = "arn:aws:s3:::acme-technologies-billing-123456789012"
  }

  expect_failures = [var.bucket]
}

run "rejects_an_uppercase_bucket" {
  command = plan

  variables {
    bucket = "Acme-Billing"
  }

  expect_failures = [var.bucket]
}

run "rejects_a_two_character_bucket" {
  command = plan

  variables {
    bucket = "ab"
  }

  expect_failures = [var.bucket]
}

run "rejects_a_bucket_ending_in_a_hyphen" {
  command = plan

  variables {
    bucket = "acme-billing-"
  }

  expect_failures = [var.bucket]
}

run "rejects_adjacent_periods_in_the_bucket" {
  command = plan

  variables {
    bucket = "acme..billing"
  }

  expect_failures = [var.bucket]
}

run "rejects_a_bucket_shaped_like_an_ip_address" {
  command = plan

  variables {
    bucket = "192.168.5.4"
  }

  expect_failures = [var.bucket]
}

run "rejects_an_empty_prefix" {
  command = plan

  variables {
    prefix = ""
  }

  expect_failures = [var.prefix]
}

run "rejects_a_leading_slash" {
  command = plan

  variables {
    prefix = "/raw/project=rusty-chess"
  }

  expect_failures = [var.prefix]
}

run "rejects_a_trailing_slash" {
  command = plan

  variables {
    prefix = "raw/project=rusty-chess/"
  }

  expect_failures = [var.prefix]
}

run "rejects_a_doubled_slash" {
  command = plan

  variables {
    prefix = "raw//project=rusty-chess"
  }

  expect_failures = [var.prefix]
}

# `*` and `?` are IAM wildcards: either would widen the grant past one prefix.
run "rejects_a_wildcard_in_the_prefix" {
  command = plan

  variables {
    prefix = "raw/project=*"
  }

  expect_failures = [var.prefix]
}

run "rejects_a_question_mark_in_the_prefix" {
  command = plan

  variables {
    prefix = "raw/project=rusty-che?s"
  }

  expect_failures = [var.prefix]
}
