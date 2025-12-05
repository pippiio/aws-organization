#!/usr/bin/env bash
set -euo pipefail

PROFILE="$1"
OIDC_URL="oidc-provider/token.actions.githubusercontent.com"

# Query AWS for the OIDC provider
ARN=$(aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[].Arn" --output text --profile "$PROFILE")

if echo "$ARN" | grep -q "$OIDC_URL"; then
  echo '{"exists": "true"}'
else
  echo '{"exists": "false"}'
fi