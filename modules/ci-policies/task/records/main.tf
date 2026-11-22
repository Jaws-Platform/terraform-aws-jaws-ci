locals {
  # For the task role: write one event record per task-run event under the
  # project's prefix, and nothing else. The writer puts each record once with
  # If-None-Match, which needs no permission beyond s3:PutObject.
  policy = {
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "PutTaskRecords"
        Effect   = "Allow"
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${var.bucket}/${var.prefix}/*"
      },
    ]
  }
}

resource "aws_iam_policy" "this" {
  name        = var.name
  description = "CI policy task/records: write task-run records under one prefix of one bucket"
  policy      = jsonencode(local.policy)

  tags = {
    Component = "ci"
  }
}
