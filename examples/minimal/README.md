# Minimal

The smallest configuration the module accepts. Three inputs are required:

| Input | Purpose |
|---|---|
| `break_glass_accounts` | Between 1 and 5 IAM users in the management account that retain access if Identity Center is unavailable |
| `master_account_email` | Base address used to generate member account emails |
| `master_account_github_repo` | Repository allowed to assume the management account OIDC role |

Even at this size the module still creates the full landing zone baseline:

- Organizational units **Security**, **Infrastructure**, **Policy Staging**,
  **Exceptions**, **Suspended** and **Workloads** (with **Production** and
  **Non Production** children).
- The mandatory accounts *Log archive*, *Security tooling*, *Backup*,
  *Network* and *Policy Stage*, with emails derived from
  `master_account_email` (`aws+log_archive@example.com` and so on).
- An organization wide CloudTrail with a log group and an S3 bucket in the
  Log archive account, encrypted with a customer managed KMS key.
- The `Corporate`, `Organization`, `Security`, `Network` and `Suspended`
  service control policies.
- A GitHub OIDC provider and role in the management account.

## Run

```console
terraform init
terraform apply
```

See [docs/getting-started.md](../../docs/getting-started.md) for prerequisites
and the two phase first apply.
