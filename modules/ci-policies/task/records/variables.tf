variable "name" {
  description = "Name of the managed policy, for example `acme-chess-bot-ci-task-task-records`."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9+=,.@_-]{1,128}$", var.name))
    error_message = "name must be a valid IAM policy name: 1-128 characters from `A-Z a-z 0-9 + = , . @ _ -`."
  }
}

variable "bucket" {
  description = "Name (not ARN) of the bucket the task-run records are written to, for example `acme-billing-123456789012`."
  type        = string

  validation {
    condition = (
      can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket)) &&
      !strcontains(var.bucket, "..") &&
      !can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$", var.bucket))
    )
    error_message = "bucket must be an S3 bucket name, not an ARN: 3-63 lowercase letters, digits, hyphens and periods, starting and ending with a letter or digit, without adjacent periods and not shaped like an IP address."
  }
}

variable "prefix" {
  description = "Key prefix of the project's records, without a leading or trailing slash, for example `raw/provider=acme/source=task-runs/project=chess-bot`. The policy covers every object under `<prefix>/`."
  type        = string

  validation {
    condition     = can(regex("^[^/*?]+(/[^/*?]+)*$", var.prefix))
    error_message = "prefix must be a non-empty S3 key prefix without a leading or trailing slash, without doubled slashes and without `*` or `?` anywhere, because both are IAM wildcards (e.g. `raw/provider=acme/source=task-runs/project=chess-bot`)."
  }
}
