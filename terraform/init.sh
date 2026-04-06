#!/bin/bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
terraform init -backend-config="bucket=tfstate-my-infra-poc-${ACCOUNT_ID}" "$@"
