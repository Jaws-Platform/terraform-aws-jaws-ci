variable "name" {
  description = "Name of the managed policy, for example `acme-monitoring-ci-apply-monitoring-node`."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9+=,.@_-]{1,128}$", var.name))
    error_message = "name must be a valid IAM policy name: 1-128 characters from `A-Z a-z 0-9 + = , . @ _ -`."
  }
}

variable "name_root" {
  description = "Prefix of resource names, in kebab-case. The monitoring stack names everything from `<name_root>-<project>`: roles, functions, schedules, alarms, the topic and the vault are `<name_root>-<project>` or `<name_root>-<project>-*`, parameters `/<name_root>-<project>/*`."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", var.name_root))
    error_message = "name_root must be kebab-case: lowercase letters, digits and single hyphens."
  }
}

variable "project" {
  description = "Project name in kebab-case. Role and instance profile ARNs are built from `<name_root>-<project>`; EC2 is scoped by the `Project = <project>` tag the provider's `default_tags` put on every resource."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", var.project))
    error_message = "project must be kebab-case: lowercase letters, digits and single hyphens (e.g. `monitoring`)."
  }
}

