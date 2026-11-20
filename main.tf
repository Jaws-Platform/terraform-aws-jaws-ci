# Root module: the plan and apply roles of one project, the pair a repository
# that runs Terraform from GitHub Actions needs.
#
#   <name_root>-<project>-ci-plan   assumed by the repository's pull requests:
#                                   read policies only
#   <name_root>-<project>-ci-apply  assumed by jobs in one GitHub environment:
#                                   read and write policies
#
# Each role gets one managed policy per entry of its policy list, built by
# ci-policies from the shared policy_inputs. The root only wires the two
# submodules together. Each can be used on its own, and both keep their own
# input validation.

module "plan" {
  source = "./modules/ci-plan-role"

  name_root                  = var.name_root
  project                    = var.project
  repository                 = var.repository
  repository_aliases         = var.repository_aliases
  repository_alias_owner_ids = var.repository_alias_owner_ids
  owner_id                   = var.owner_id
  repository_id              = var.repository_id
  oidc_provider_arn          = var.oidc_provider_arn

  policies      = var.plan_policies
  policy_inputs = var.policy_inputs
}

module "apply" {
  source = "./modules/ci-apply-role"

  name_root                  = var.name_root
  project                    = var.project
  repository                 = var.repository
  repository_aliases         = var.repository_aliases
  repository_alias_owner_ids = var.repository_alias_owner_ids
  owner_id                   = var.owner_id
  repository_id              = var.repository_id
  oidc_provider_arn          = var.oidc_provider_arn
  environment                = var.environment

  policies      = var.apply_policies
  policy_inputs = var.policy_inputs
}
