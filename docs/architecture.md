# What the module builds

The module runs against the **AWS Organizations management account** and
provisions a landing zone: the organization itself, an organizational unit
tree, member accounts, guardrails, audit logging and access.

## Organizational unit tree

Five units are always created, regardless of `config.units`. Everything you
declare is merged into them.

```text
Root
|-- Security               always created
|   |-- Log archive        always created
|   `-- Security tooling   always created
|-- Infrastructure         always created
|   |-- Backup             always created
|   `-- Network            always created
|-- Policy Staging         always created
|   `-- Policy Stage       always created
|-- Exceptions             always created, skipped by the Corporate attachment
|-- Suspended              always created, Suspended (deny all) policy
`-- Workloads              default when config.units is not set
    |-- Production
    `-- Non Production
```

Unit keys are lower case and become titled OU names: `policy_staging` renders
as *Policy Staging*, and underscores become spaces. Child units are one level
deep: a child unit cannot itself have children.

Allowed unit keys are `security`, `infrastructure`, `workloads`, `sandbox`,
`individual`, `transitional`, `deployments`, `exceptions` and `policy_staging`.
Anything else fails variable validation.

### Mandatory accounts

These five accounts exist whether or not you declare them. If you do declare
one, only its `email` is taken from your configuration; the other fields keep
the module defaults.

| Account | Unit | Generated email | Notes |
|---|---|---|---|
| Log archive | Security | `<local>+log_archive@<domain>` | Holds the CloudTrail S3 bucket |
| Security tooling | Security | `<local>+security_tooling@<domain>` | For GuardDuty, Security Hub and similar |
| Backup | Infrastructure | `<local>+backup@<domain>` | |
| Network | Infrastructure | `<local>+network@<domain>` | The `Network` policy is attached to it |
| Policy Stage | Policy Staging | `<local>+policy@<domain>` | For testing policies before rollout |

`<local>` and `<domain>` come from `config.master_account_email`, so
`aws@example.com` produces `aws+log_archive@example.com`. Set an explicit
`email` on the account to override this.

Every member account gets an `OrganizationAccountAccessRole`, and
`name`, `email` and `role_name` are held under `lifecycle.ignore_changes` so
renaming an account in configuration does not force replacement.
Accounts use `close_on_deletion = false`: removing an account from
configuration removes it from the organization but does not close it.

## Organization settings

`feature_set = "ALL"` with the `SERVICE_CONTROL_POLICY`, `TAG_POLICY` and
`BACKUP_POLICY` policy types enabled. Trusted service access is granted to
`cloudtrail.amazonaws.com`, `account.amazonaws.com`, `sso.amazonaws.com` and,
unless `config.backup.disabled` is true, `backup.amazonaws.com`.

## Audit logging

- An organization CloudTrail named `<name_prefix>organization-cloudtrail`:
  multi region, all member accounts, global service events, log file
  validation, and both `ApiCallRateInsight` and `ApiErrorRateInsight`.
- A CloudWatch log group `<name_prefix>cloudtrail-logs` in the management
  account, KMS encrypted, **7 day** retention.
- An S3 bucket `<name_prefix>cloudtrail-<log archive account id>-<region>` in
  the **Log archive** account: versioned, SSE-KMS, public access blocked,
  TLS-only bucket policy, and a **180 day** expiration lifecycle rule. The
  bucket carries `prevent_destroy = true`.
- A CloudTrail event data store `<name_prefix>events`, organization wide,
  multi region, 180 day retention.
- A customer managed KMS key with rotation enabled, aliased
  `alias/organization`, used for the trail, the log group, the event data
  store and the generated `SecureString` SSM parameters.

To create resources inside the Log archive account, the module creates an IAM
user `LogArchiveAssumer` in the management account with an access key, and
configures an aliased provider that uses it to assume
`OrganizationAccountAccessRole` in that account.

## Break glass access

`config.break_glass_accounts` creates IAM users in the management account,
placed in a `BreakGlassAccess` group with `AdministratorAccess` and a policy
that denies everything except MFA self-management when MFA is not present.
Each user gets a console login profile with a 20 character generated password
and `password_reset_required`.

The passwords are returned by the `break_glass_access` output and therefore
land in state. Sign in once per user, rotate the password and enrol MFA, then
treat the output as stale.

## CI/CD access

- The management account always gets a GitHub OIDC provider and a role named
  `GitHubActionsRole-<management account name>`, trusted by
  `config.master_account_github_repo`.
- Any account with a non-empty `github` list gets its own OIDC provider and a
  `GitHubActionsRole-<account name>` role with `AdministratorAccess`. The role
  arn is published to `/account/<account id>/aws_oidc_assume_role_arn` in the
  management account.
- Any account with `create_iam_user = true` gets an IAM user in the
  **management** account, named after the member account id, permitted only to
  assume that account's `OrganizationAccountAccessRole`. Credentials are
  written to `/account/<account id>/aws_access_key_id`,
  `/account/<account id>/aws_secret_access_key` (SecureString, module KMS key)
  and `/account/<account id>/aws_assume_role_arn`.

## Identity Center

See [the Identity Center example](../examples/identity-center) for permission
sets, groups, users and the inheritance rules.
