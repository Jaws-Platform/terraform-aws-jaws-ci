mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
    }
  }

  # github-oidc-role checks that what it attaches is a policy ARN. The roles
  # keep the mock's generated ARNs, which differ from each other.
  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::123456789012:policy/mock"
    }
  }
}

variables {
  name_root         = "acme"
  project           = "guitar"
  repository        = "acme/guitar"
  oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"

  plan_policies  = ["tfstate/read", "static-site/read"]
  apply_policies = ["tfstate/write", "static-site/read", "static-site/deploy"]

  policy_inputs = {
    tfstate = {
      bucket_arn = "arn:aws:s3:::acme-tfstate"
      prefix     = "project=guitar/"
    }
    static_site = {
      bucket_arn   = "arn:aws:s3:::acme-guitar"
      zone_id      = "Z0123456789ABCDEFGHIJ"
      record_names = ["guitar.example.com", "*.preview.guitar.example.com"]
    }
  }
}

# The trust policies and the policy documents are not outputs of the role
# modules, and a test cannot look inside a child module, so they are tested
# where they are built: in ci-plan-role, ci-apply-role, github-oidc-role and
# ci-policies. These runs pin what the root adds, which is the wiring.

run "a_plan_role_and_an_apply_role" {
  command = apply

  assert {
    condition     = output.plan_role_name == "acme-guitar-ci-plan" && output.apply_role_name == "acme-guitar-ci-apply"
    error_message = "the roles must be named <name_root>-<project>-ci-plan and <name_root>-<project>-ci-apply"
  }

  assert {
    condition     = output.plan_role_name == module.plan.role_name && output.plan_role_arn == module.plan.role_arn
    error_message = "the plan role outputs must be the ci-plan-role module's outputs"
  }

  assert {
    condition     = output.apply_role_name == module.apply.role_name && output.apply_role_arn == module.apply.role_arn
    error_message = "the apply role outputs must be the ci-apply-role module's outputs"
  }

  assert {
    condition     = output.plan_role_arn != output.apply_role_arn
    error_message = "the two outputs must be two different roles"
  }
}

run "each_role_gets_its_own_policies" {
  command = apply

  assert {
    condition     = sort(keys(output.plan_policy_arns)) == tolist(["static-site/read", "tfstate/read"])
    error_message = "the plan role must hold exactly plan_policies"
  }

  assert {
    condition     = sort(keys(output.apply_policy_arns)) == tolist(["static-site/deploy", "static-site/read", "tfstate/write"])
    error_message = "the apply role must hold exactly apply_policies"
  }

  assert {
    condition     = output.plan_policy_arns == module.plan.policy_arns && output.apply_policy_arns == module.apply.policy_arns
    error_message = "the policy outputs must be the role modules' policy_arns"
  }

  assert {
    condition     = alltrue([for arn in concat(values(output.plan_policy_arns), values(output.apply_policy_arns)) : arn != null])
    error_message = "every requested policy must have an ARN"
  }
}

run "policies_that_need_no_inputs" {
  command = plan

  variables {
    plan_policies  = ["compute/read"]
    apply_policies = ["compute/read", "compute/manage"]
    policy_inputs  = {}
  }

  assert {
    condition     = sort(keys(output.plan_policy_arns)) == tolist(["compute/read"])
    error_message = "compute/read needs no policy_inputs section"
  }

  assert {
    condition     = sort(keys(output.apply_policy_arns)) == tolist(["compute/manage", "compute/read"])
    error_message = "compute/manage needs no policy_inputs section"
  }
}

# The account's own stack: one state object rather than a prefix, and the
# foundation policies, which are built from the OIDC provider's ARN too.
run "one_state_key_and_the_foundation_policies" {
  command = plan

  variables {
    project        = "infra"
    repository     = "acme/infra"
    plan_policies  = ["tfstate/read", "foundation/read"]
    apply_policies = ["tfstate/write", "foundation/read", "foundation/manage"]

    policy_inputs = {
      tfstate = {
        bucket_arn = "arn:aws:s3:::acme-tfstate"
        key        = "project=infra/env=prod/infra-prod.tfstate"
      }
      foundation = {
        state_bucket_arn = "arn:aws:s3:::acme-tfstate"
        hosted_zone_arn  = "arn:aws:route53:::hostedzone/Z0123456789ABCDEFGHIJ"
      }
    }
  }

  assert {
    condition     = output.plan_role_name == "acme-infra-ci-plan" && output.apply_role_name == "acme-infra-ci-apply"
    error_message = "the role names must follow project"
  }

  assert {
    condition     = sort(keys(output.plan_policy_arns)) == tolist(["foundation/read", "tfstate/read"])
    error_message = "the plan role must hold the foundation read policy"
  }

  assert {
    condition     = sort(keys(output.apply_policy_arns)) == tolist(["foundation/manage", "foundation/read", "tfstate/write"])
    error_message = "the apply role must hold the foundation read and manage policies"
  }
}

# environment, the GitHub IDs and the aliases only change the trust policies,
# which the root cannot see. The next two runs pin that the root accepts them
# and that they change nothing else; ci-apply-role and github-oidc-role test
# what they do to the trust policy.
run "another_environment_is_passed_through" {
  command = plan

  variables {
    environment = "staging-eu"
  }

  assert {
    condition     = output.apply_role_name == "acme-guitar-ci-apply" && output.plan_role_name == "acme-guitar-ci-plan"
    error_message = "environment changes whom the apply role trusts, never a role name"
  }

  assert {
    condition     = length(output.apply_policy_arns) == 3 && length(output.plan_policy_arns) == 2
    error_message = "environment must not change the policies"
  }
}

run "github_ids_and_a_repository_alias_are_passed_through" {
  command = plan

  variables {
    owner_id           = "12345678"
    repository_id      = "123456789"
    repository_aliases = ["acme/six-strings"]
  }

  assert {
    condition     = output.plan_role_name == "acme-guitar-ci-plan" && output.apply_role_name == "acme-guitar-ci-apply"
    error_message = "the IDs and aliases change whom the roles trust, never a role name"
  }

  assert {
    condition     = length(output.plan_policy_arns) == 2 && length(output.apply_policy_arns) == 3
    error_message = "the IDs and aliases must not change the policies"
  }
}
