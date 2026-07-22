#!/usr/bin/env bash
# Creates the S3 bucket used for reference files, intermediate results,
# and final outputs. Bucket name + region come from config/config.yaml.
set -euo pipefail

# Run this from the repo root: bash aws/create_s3_bucket.sh
AWS_REGION=$(grep -A2 "^aws:" config/config.yaml | grep region | awk '{print $2}' | tr -d '"')
BUCKET=$(grep -A6 "^aws:" config/config.yaml | grep s3_bucket | awk '{print $2}' | tr -d '"')

if [[ "$BUCKET" == *"CHANGE-ME"* ]]; then
  echo "Edit config/config.yaml -> aws.s3_bucket to a globally-unique name first." >&2
  exit 1
fi

echo "==> Creating bucket: s3://${BUCKET} in ${AWS_REGION}"
if [ "$AWS_REGION" == "us-east-1" ]; then
  aws s3api create-bucket --bucket "${BUCKET}" --region "${AWS_REGION}"
else
  aws s3api create-bucket --bucket "${BUCKET}" --region "${AWS_REGION}" \
    --create-bucket-configuration LocationConstraint="${AWS_REGION}"
fi

echo "==> Blocking public access (this bucket holds genomic data)"
aws s3api put-public-access-block --bucket "${BUCKET}" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "==> Enabling default encryption"
aws s3api put-bucket-encryption --bucket "${BUCKET}" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

echo "==> Done: s3://${BUCKET}"
