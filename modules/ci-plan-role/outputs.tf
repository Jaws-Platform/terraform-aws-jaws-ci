output "role_arn" {
  description = "ARN of the role, for `role-to-assume` in `aws-actions/configure-aws-credentials`."
  value       = module.role.arn
}

output "role_name" {
  description = "Name of the role."
  value       = module.role.name
}

output "policy_arns" {
  description = "Map of requested policy (for example `static-site/read`) to the ARN of the managed policy created for it and attached to the role."
  value       = module.policies.arns
}

output "assume_role_policy" {
  description = "The role's trust policy, as JSON, so a caller can test who may assume the role."
  value       = module.role.assume_role_policy
}
