variable "name" {
  description = "Name of the managed policy, for example `acme-monitoring-ci-apply-monitoring-config`."
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
  description = "Project name in kebab-case. Every resource ARN in the policy is built from `<name_root>-<project>`."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", var.project))
    error_message = "project must be kebab-case: lowercase letters, digits and single hyphens (e.g. `monitoring`)."
  }
}

variable "zone_id" {
  description = "Route 53 hosted zone of the node's record (the monitoring module's `zone_id`). Null, with a null `domain`: the stack has no record and the policy changes nothing in Route 53."
  type        = string
  default     = null

  validation {
    condition     = var.zone_id == null || can(regex("^Z[A-Z0-9]{5,31}$", var.zone_id))
    error_message = "zone_id must be a Route 53 hosted zone ID (e.g. `Z0123456789ABCDEFGHIJ`), or null."
  }
}

variable "domain" {
  description = "The node's record (the monitoring module's `domain`), for example `grafana.example.com`. With `zone_id`, the policy may change that one record in that zone. Null, with a null `zone_id`: the stack has no record and the policy changes nothing in Route 53."
  type        = string
  default     = null

  validation {
    condition     = var.domain == null || can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}\\.?$", var.domain))
    error_message = "domain must be a lowercase FQDN such as `grafana.example.com`, without a wildcard, or null."
  }

  validation {
    condition     = (var.domain == null) == (var.zone_id == null)
    error_message = "domain and zone_id go together: set both for a node with a record, or neither."
  }
}
