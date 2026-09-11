# GitHub Actions access

Grants CI/CD pipelines access to member accounts, either through GitHub OIDC
(`github`) or through generated static credentials (`create_iam_user`).

## Using the role from a workflow

The role arn is stored in the management account as
`/account/<account id>/aws_oidc_assume_role_arn`, and the role is named
`GitHubActionsRole-<account name>` (lower cased, spaces and dots replaced with
dashes).

```yaml
permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::111122223333:role/GitHubActionsRole-dev
          aws-region: eu-west-1
```

## Trust scope

The trust policy matches `repo:<org>/<repo>:*`, meaning **any** branch, tag,
pull request or environment of the listed repositories can assume the role, and
the role holds `AdministratorAccess`. Restrict who can push to those
repositories accordingly, or protect the deployment through GitHub environments.
