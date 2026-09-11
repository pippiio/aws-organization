# IAM Identity Center

Sets up groups, users and account assignments in IAM Identity Center.

**Prerequisite:** Identity Center must already be enabled in the management
account. The module reads the existing instance with
`data "aws_ssoadmin_instances"`; it does not enable the service. Omitting
`config.sso` entirely disables all Identity Center handling in the module.

## Permission sets

The module creates four permission sets. Reference them by the key in the left
column from any `group` or `user` map.

| Key | Permission set | Policy | Session |
|---|---|---|---|
| `administrator` | `Administrator` | `AdministratorAccess` | 1 hour |
| `contributor` | `Contributor` | `PowerUserAccess` plus an inline policy for IAM role management | 10 hours |
| `billing` | `Billing` | `job-function/Billing` | 1 hour |
| `read_only` | `ReadOnly` | `ReadOnlyAccess` | 2 hours |

## Inheritance

`group` can be set on a unit, on a child unit and on an account. The three
maps are merged for each account, and permission sets for the same group are
unioned rather than replaced. In this example, an account under
`workloads/Non Production` ends up with `DevOps = ["contributor"]` from the
parent unit and `Developers = ["contributor"]` from the child unit.

`user` is only available on accounts and is never inherited. Prefer groups;
use direct user assignments only for genuine exceptions.

`management_account_permissions` is set on a **group**, and grants that group a
permission set on the management account itself.

## Naming

`full_name` is split on spaces into a given name and a family name, so it must
contain exactly two words. The map key is the sign-in user name.
