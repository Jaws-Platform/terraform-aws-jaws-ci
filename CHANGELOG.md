# Changelog

## [0.6.0](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/compare/v0.5.0...v0.6.0) (2026-11-23)


### Features

* **ci-policies:** let monitoring ci roles manage the node's off-hours page ([#27](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/issues/27)) ([4ac88be](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/commit/4ac88beeee5a67533139eece258651ecb4ef763b))

## [0.5.0](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/compare/v0.4.0...v0.5.0) (2026-11-23)


### Features

* **ci-apply-role:** trust other repositories and expose the trust policy ([480993f](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/commit/480993fa2b345f9a8aa01682496b6c7d48487555))
* **ci-plan-role:** trust other repositories and expose the trust policy ([bc5c928](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/commit/bc5c928a768a14b4002e22aade0a3b5848575c00))
* **ci-policies:** grant ecr pull and push on more than one repository ([#26](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/issues/26)) ([a298fc2](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/commit/a298fc219e622385d6fdd150bd9c30cf14f08f23))
* **examples:** pass other trusted repositories through the root module ([fdf4e28](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/commit/fdf4e2878fb16cae07d94b18df804ba0fe8cae71))
* **github-oidc-role:** trust other repositories under their own ids ([4830fe7](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/commit/4830fe7fb5d2001b6c049bc235339dc056888798))

## [0.4.0](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/compare/v0.3.0...v0.4.0) (2026-11-22)


### Features

* **ci-policies:** add task/records for task-run records ([#22](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/issues/22)) ([83ac5ef](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/commit/83ac5ef78155774fc29eba2bdc32a2112f0ba47f))

## [0.3.0](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/compare/v0.2.0...v0.3.0) (2026-11-22)


### Features

* **ci-policies:** add the monitoring family for the monitoring stack ([#20](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/issues/20)) ([8e55d85](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/commit/8e55d8543aa4fdf7bd8295d7aae8ca7220ae7991))

## [0.2.0](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/compare/v0.1.3...v0.2.0) (2026-11-20)


### Features

* **github-oidc-role:** trust a transferred repository under its new owner's id ([#7](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/issues/7)) ([8f8f206](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/commit/8f8f206bc76a1783e1a4c593b094bcee57b557b1))

## [0.1.3](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/compare/v0.1.2...v0.1.3) (2026-11-20)


### Miscellaneous Chores

* list chore commits in the changelog for the 0.1.3 release ([#14](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/issues/14)) ([6c9dc66](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/commit/6c9dc66aab8981a99b3db675718c3c1f9361c500))
* release 0.1.3 so the registry shows the newest version as latest ([#13](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/issues/13)) ([7d31903](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/commit/7d319036648a6f8b51ff190006983e9eec6095cf))

## [0.1.2](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/compare/v0.1.1...v0.1.2) (2026-11-20)


### Bug Fixes

* name the organization Jaws-Platform in addresses and links ([#11](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/issues/11)) ([9c57be8](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/commit/9c57be867a8fccba1f5efc9265cd44b6c8aa3ac1))

## [0.1.1](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/compare/v0.1.0...v0.1.1) (2026-11-20)


### Bug Fixes

* move the registry address and links to the Jaws-Platform organization ([#6](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/issues/6)) ([e00f117](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/commit/e00f1176b2a1d0ee92e9b76ca54ec0c213598876))
* use the lowercase jaws-platform namespace in addresses and links ([#8](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/issues/8)) ([b5b6a3b](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/commit/b5b6a3be577b9b348b0e0bb51566b6dfc21f46be))

## 0.1.0 (2026-11-20)


### Features

* add the github oidc role modules, the policy catalog and the plan and apply root module ([#4](https://github.com/jwallace145/terraform-aws-jaws-ci/issues/4)) ([f3e8889](https://github.com/jwallace145/terraform-aws-jaws-ci/commit/f3e8889ac16795761b7046e80a315ca6f3c174b5))
