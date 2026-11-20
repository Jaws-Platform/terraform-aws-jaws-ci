output "plan_role_arn" {
  description = "ARN of the plan role, for `role-to-assume` in `aws-actions/configure-aws-credentials` in pull request workflows."
  value       = module.plan.role_arn
}

output "plan_role_name" {
  description = "Name of the plan role, `<name_root>-<project>-ci-plan`."
  value       = module.plan.role_name
}

output "plan_policy_arns" {
  description = "Map of each entry of `plan_policies` (for example `tfstate/read`) to the ARN of the managed policy created for it and attached to the plan role."
  value       = module.plan.policy_arns
}

output "apply_role_arn" {
  description = "ARN of the apply role, for `role-to-assume` in `aws-actions/configure-aws-credentials` in jobs that run in `environment`."
  value       = module.apply.role_arn
}

output "apply_role_name" {
  description = "Name of the apply role, `<name_root>-<project>-ci-apply`."
  value       = module.apply.role_name
}

output "apply_policy_arns" {
  description = "Map of each entry of `apply_policies` (for example `tfstate/write`) to the ARN of the managed policy created for it and attached to the apply role."
  value       = module.apply.policy_arns
}
