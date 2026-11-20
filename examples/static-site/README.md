# Static site: plan, apply and preview roles

The three roles the workflows of a static site repository, `acme/guitar`,
assume through GitHub OIDC:

| Role | Assumed by | Policies |
|---|---|---|
| `acme-guitar-ci-plan` | any pull request in the repository | `tfstate/read`, `static-site/read` |
| `acme-guitar-ci-preview` | any pull request in the repository | `static-site/previews` |
| `acme-guitar-ci-apply` | jobs in the `prod` environment | `tfstate/write`, `static-site/read`, `static-site/deploy` |

The root module creates the plan and apply pair, and the
[`ci-preview-role`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-preview-role)
submodule adds the third. All three are built from the same `policy_inputs`:
the project's state prefix, its site bucket, the hosted zone and the record
names it may change.

The state bucket, the site bucket and the hosted zone are literals here, so
the example needs nothing but the account's GitHub Actions OIDC provider,
which it looks up. In a real stack they are outputs of the modules that
create them, for example
[`tfstate-bucket`](https://registry.terraform.io/modules/Jaws-Platform/jaws-foundation/aws/latest/submodules/tfstate-bucket),
[`site-bucket`](https://registry.terraform.io/modules/Jaws-Platform/jaws-static-site/aws/latest/submodules/site-bucket)
and
[`hosted-zone`](https://registry.terraform.io/modules/Jaws-Platform/jaws-static-site/aws/latest/submodules/hosted-zone).

```sh
terraform init
terraform plan
```

In your own configuration, replace the relative `source` with the registry
address:

```hcl
module "ci" {
  source  = "Jaws-Platform/jaws-ci/aws"
  version = "0.2.0" # x-release-please-version

  name_root         = "acme"
  project           = "guitar"
  repository        = "acme/guitar"
  oidc_provider_arn = data.aws_iam_openid_connect_provider.github.arn

  plan_policies  = ["tfstate/read", "static-site/read"]
  apply_policies = ["tfstate/write", "static-site/read", "static-site/deploy"]
  policy_inputs  = local.policy_inputs
}

module "ci_preview" {
  source  = "Jaws-Platform/jaws-ci/aws//modules/ci-preview-role"
  version = "0.2.0" # x-release-please-version

  name_root         = "acme"
  project           = "guitar"
  repository        = "acme/guitar"
  oidc_provider_arn = data.aws_iam_openid_connect_provider.github.arn

  policies      = ["static-site/previews"]
  policy_inputs = local.policy_inputs
}
```
