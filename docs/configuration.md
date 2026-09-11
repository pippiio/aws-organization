# Configuration reference

The module takes one large `config` object plus two conventional pippi.io
inputs. Every field below is a key of `var.config` unless stated otherwise.

## Module inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `config` | `object` | n/a | The whole configuration, described below |
| `name_prefix` | `string` | `"pippi-"` | Prefix for named resources in the management account. Must match `^[a-zA-Z-]*$` |
| `default_tags` | `map(string)` | `{}` | Merged into the tags of every taggable resource |

The module always adds `tf-module = "pippi.io/aws-organization"` and
`tf-workspace = <workspace>` to `default_tags`.

## Required

| Field | Type | Description |
|---|---|---|
| `break_glass_accounts` | `set(string)` | 1-5 IAM user names created in the management account. Two to four is recommended |
| `master_account_email` | `string` | Base address for generated member account emails. `aws@example.com` yields `aws+network@example.com` |
| `master_account_github_repo` | `string` | `"<org>/<repo>"` trusted by the management account GitHub OIDC role |

## Optional

| Field | Type | Default | Description |
|---|---|---|---|
| `enabled_regions` | `set(string)` | `[]` | Regions member accounts may use. Empty falls back to the provider's region. Validated against the AWS region name pattern |
| `units` | `map(unit)` | Workloads with Production and Non Production | The organizational unit tree |
| `policies.scp` | `map(policy)` | `{}` | Custom service control policies |
| `sso` | `object` | `null` | Identity Center configuration. `null` disables all Identity Center resources |
| `backup` | `object` | `{}` | Organization level backup settings |
| `backup.disabled` | `bool` | `false` | When true, `backup.amazonaws.com` is left out of the organization's trusted service access |
| `github_oidc_thumbprints` | `set(string)` | GitHub's two current thumbprints | Thumbprints for the OIDC providers |

## `units`

Key must be one of `security`, `infrastructure`, `workloads`, `sandbox`,
`individual`, `transitional`, `deployments`, `exceptions`, `policy_staging`.

| Field | Type | Default | Description |
|---|---|---|---|
| `tags` | `map(string)` | `{}` | Tags for the organizational unit |
| `approved_services` | `set(string)` | `[]` | IAM service prefixes such as `ec2` or `s3`. Non-empty generates an `Approved<Unit>` policy denying everything else, attached to this unit |
| `scp` | `set(string)` | `[]` | Names of service control policies to attach. Built in names are `security`, `network` and `suspended`; anything else must be a key of `policies.scp` |
| `group` | `map(set(string))` | `{}` | Identity Center group name to permission set keys, granted on every account under this unit |
| `accounts` | `map(account)` | `{}` | Accounts directly under this unit. The map key is the account name |
| `children` | `map(child)` | `{}` | One level of nested units. The map key is the OU name |

### `children.<name>`

Same as a unit minus `approved_services` and `children`: `tags`, `scp`,
`group` and `accounts`.

### `accounts.<name>`

| Field | Type | Default | Description |
|---|---|---|---|
| `email` | `string` | n/a | Required. Must be globally unique across AWS |
| `tags` | `map(string)` | `{}` | Tags for the account |
| `group` | `map(set(string))` | `{}` | Group grants on this account, merged with the ones inherited from the unit and child unit |
| `user` | `map(set(string))` | `{}` | Direct Identity Center user grants. Keys must exist in `sso.users`. Not inherited |
| `create_iam_user` | `bool` | `false` | Creates a management account IAM user and access key that can assume this account's `OrganizationAccountAccessRole` |
| `github` | `set(string)` | `[]` | `"<org>/<repo>"` entries allowed to assume a `GitHubActionsRole-<account>` role with `AdministratorAccess` in this account |
| `scp` | `set(string)` | `[]` | Accepted by the schema but **not currently attached**, see [Known quirks](#known-quirks) |

## `policies.scp.<name>`

| Field | Type | Default | Description |
|---|---|---|---|
| `content` | `string` | n/a | Required. The policy JSON, typically from `jsonencode(...)` or `file(...)` |
| `description` | `string` | n/a | Required |
| `tags` | `map(string)` | `{}` | |

The map key becomes both the policy name in AWS and the name you reference
from a `scp` list.

## `sso`

Omit the whole object to skip Identity Center. Identity Center must already be
enabled in the management account; the module reads the existing instance.

| Field | Type | Default | Description |
|---|---|---|---|
| `groups` | `map(object)` | n/a | Required when `sso` is set. Key is the group display name |
| `groups.<name>.description` | `string` | n/a | Required |
| `groups.<name>.management_account_permissions` | `set(string)` | `[]` | Permission set keys granted to this group on the management account |
| `users` | `map(object)` | `{}` | Key is the sign-in user name |
| `users.<name>.full_name` | `string` | n/a | Required. Split on spaces into given and family name, so exactly two words |
| `users.<name>.email` | `string` | n/a | Required |
| `users.<name>.groups` | `set(string)` | n/a | Required. Group memberships; keys must exist in `sso.groups` |

Permission set keys usable in `group`, `user` and
`management_account_permissions`:

| Key | Permission set | Managed policy | Session duration |
|---|---|---|---|
| `administrator` | `Administrator` | `AdministratorAccess` | 1 hour |
| `contributor` | `Contributor` | `PowerUserAccess` plus inline IAM role management | 10 hours |
| `billing` | `Billing` | `job-function/Billing` | 1 hour |
| `read_only` | `ReadOnly` | `ReadOnlyAccess` | 2 hours |

## Outputs

| Name | Description |
|---|---|
| `organization` | The organization id |
| `enabled_regions` | The configured `enabled_regions` |
| `accounts` | List of every member account with `name`, `email`, `id`, `ou` and the `permissions` assigned directly to it |
| `network_account` | `id` and `assume_role_arn` for the Network account |
| `organization_role_name` | `OrganizationAccountAccessRole` |
| `break_glass_access` | Per break glass user: `username`, generated `password` and console sign-in URL. **Contains secrets**, so mark it `sensitive` when re-exporting |

## Known quirks

These are current behaviours of the module worth knowing before you hit them.

- **Account level `scp` is inert.** Policy attachments are only generated for
  units and child units. Attach the policy at the unit level, or place the
  account in its own child unit.
- **`policy_staging` conflicts with the built in unit.** The module always
  injects an internal `policy staging` unit that renders as the OU *Policy
  Staging*. Passing `policy_staging` in `config.units` produces a second OU
  with the same name rather than extending the existing one. Leave it unset.
- **`suspended` cannot be configured.** The Suspended unit is always created
  with the deny-all policy, but `suspended` is not an accepted `units` key, so
  it cannot be extended. Move accounts into it out of band.
- **The `Organization` policy is created but not attached.** The root
  attachment applies the `Corporate` policy; `Organization` is created from the
  same template and left unattached.
- **`break_glass_access` passwords live in state.** Rotate after first sign-in.
