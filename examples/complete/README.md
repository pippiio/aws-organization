# Complete

Uses every input the module supports:

- `name_prefix` and `default_tags` for naming and tagging.
- `enabled_regions` to region-lock the organization.
- Custom service control policies under `policies.scp`, attached by name from
  `units.<unit>.scp` and `units.<unit>.children.<child>.scp`.
- `approved_services` on the Sandbox unit, which generates an
  `ApprovedSandbox` policy that denies everything except a base set of
  organization services plus the listed ones.
- The `exceptions` unit, which the `Corporate` attachment intentionally
  skips (see the known quirk about the root attachment in
  [docs/configuration.md](../../docs/configuration.md#known-quirks)).
- Identity Center groups, users, inherited group grants, a direct user grant
  and `management_account_permissions`.
- `github` for OIDC based CI/CD and `create_iam_user` for static credentials.
- Per unit, per child and per account `tags`.

Read it top to bottom as an annotated reference for `var.config`. For the
individual field semantics see [docs/configuration.md](../../docs/configuration.md).
