# Service control policies

The module ships five built in policies and lets you add your own. Policies
are attached to organizational units, never to individual accounts, with
one exception: the Network policy.

## Built in policies

| Name | Attached to | Effect |
|---|---|---|
| `Corporate` | The organization root, and every unit except *Policy Staging* and *Exceptions* | The main guardrail, see below |
| `Organization` | Nothing (see [known quirks](configuration.md#known-quirks)) | Created from the same template as `Corporate` |
| `Security` | The *Security* unit | Protects CloudTrail, Config, GuardDuty and `OrganizationAccountAccessRole`; denies console login creation, leaving or deleting the organization, RAM shares to external principals, and all root user activity |
| `Network` | The *Network* account | Denies everything that is not a networking, DNS, edge or certificate service, and blocks deleting hosted zones and domains |
| `Suspended` | The *Suspended* unit | Denies everything |
| `Approved<Unit>` | The unit that declared `approved_services` | Denies everything except a base set of organization services plus the listed services |

### What `Corporate` denies

- `s3:PutAccountPublicAccessBlock`, so account level public access blocks
  cannot be removed.
- Disabling or tampering with CloudTrail, AWS Config and GuardDuty.
- Creating and managing IAM users, access keys and login profiles. Access is
  meant to come from Identity Center or the OIDC roles.
- Any regional action outside `config.enabled_regions`. Global and billing
  services (IAM, KMS, Route 53, CloudFront, Organizations, Support, Shield,
  WAF, Cost Explorer and similar) are exempt.
- Lambda outside `config.enabled_regions`, plus `us-east-1` when
  `config.allow_lambda_edge` is set so CloudFront Lambda@Edge functions can be
  created there.

The first three carve out `OrganizationAccountAccessRole` and the
`Administrator` permission set, so an administrator signing in through
Identity Center or assuming the cross account role is not blocked.

### `approved_services`

Setting `approved_services` on a unit generates a policy that denies every
action outside the union of a fixed base list (`backup`, `budgets`,
`cloudtrail`, `config`, `guardduty`, `health`, `iam`, `kms`, `organizations`,
`pricing`, `shield`, `sts`, `support`, `trustedadvisor`, `wellarchitected`)
and the services you list. Values are IAM service prefixes without the
wildcard:

```hcl
sandbox = {
  approved_services = ["ec2", "s3", "lambda", "logs"]
}
```

`OrganizationAccountAccessRole` and the `Administrator` permission set are
exempt from this policy too.

## Custom policies

Declare a policy under `policies.scp` and reference it by its map key:

```hcl
config = {
  policies = {
    scp = {
      RequireImdsv2 = {
        description = "Requires IMDSv2 on newly launched EC2 instances."
        content = jsonencode({
          Version = "2012-10-17"
          Statement = [{
            Sid      = "RequireImdsv2"
            Effect   = "Deny"
            Action   = "ec2:RunInstances"
            Resource = "arn:aws:ec2:*:*:instance/*"
            Condition = {
              StringNotEquals = { "ec2:MetadataHttpTokens" = "required" }
            }
          }]
        })
      }
    }
  }

  units = {
    workloads = {
      scp = ["RequireImdsv2"]                       # whole unit

      children = {
        Production = { scp = ["RequireImdsv2"] }    # single child unit
      }
    }
  }
}
```

`scp` entries resolve against your `policies.scp` keys plus the built in names
`security`, `network` and `suspended`. An unknown name fails at plan time with
a missing map key error rather than a friendly validation message.

## Testing a policy before rolling it out

The *Policy Staging* unit and its *Policy Stage* account exist for this, and
are deliberately excluded from the `Corporate` attachment. Attach a new policy
there first, verify the effect, then widen the attachment.

Note the caveat in [known quirks](configuration.md#known-quirks): because
`Corporate` is also attached at the organization root, *Policy Staging* and
*Exceptions* still inherit it today.

## Limits to keep in mind

AWS limits an organization to 5 policies attached per target and 5120
characters per policy after whitespace removal. The module strips whitespace
from its own templates before submitting them. A unit that is region-locked by
`Corporate`, carries an `Approved<Unit>` policy and two custom policies is
already at four of five.
