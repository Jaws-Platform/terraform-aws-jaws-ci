# Foundation: the roles of an account's own stack

The plan and apply roles for the stack that owns an account's shared
resources: the Terraform state bucket, the hosted zone, and every project's
buckets, roles and policies. That stack is typically applied once per
account, and it is where the other projects' CI roles are created, so its
own two roles are created there too.

| Role | Assumed by | Policies |
|---|---|---|
| `acme-infra-ci-plan` | any pull request in `acme/infra` | `tfstate/read`, `foundation/read` |
| `acme-infra-ci-apply` | jobs in the `production` environment | `tfstate/write`, `foundation/read`, `foundation/manage` |

Two things differ from a project's roles:

- `tfstate` names one state object with `key` instead of a `prefix`, so the
  roles reach this stack's state and no other.
- `environment` is `production` rather than the default `prod`. The apply
  role trusts jobs in that GitHub environment and nothing else.

The apply role is the most privileged identity this family creates. With
`foundation/manage` it can create and edit `acme-*` roles and policies, its
own included, so protect the `production` environment with required
reviewers and restrict its deployment branches. The
[`ci-policies`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-policies)
README describes the limitation.

The roles do not exist before the first apply, so an administrator runs that
one. From then on the workflows apply every change, including changes to
these roles.

```sh
terraform init
terraform plan
```

In your own configuration, replace the relative `source` with the registry
address:

```hcl
module "ci" {
  source  = "Jaws-Platform/jaws-ci/aws"
  version = "0.5.0" # x-release-please-version

  name_root         = "acme"
  project           = "infra"
  repository        = "acme/infra"
  oidc_provider_arn = data.aws_iam_openid_connect_provider.github.arn
  environment       = "production"

  plan_policies  = ["tfstate/read", "foundation/read"]
  apply_policies = ["tfstate/write", "foundation/read", "foundation/manage"]

  policy_inputs = {
    tfstate    = { bucket_arn = local.state_bucket_arn, key = "project=infra/env=prod/terraform.tfstate" }
    foundation = { state_bucket_arn = local.state_bucket_arn, hosted_zone_arn = local.hosted_zone_arn }
  }
}
```
