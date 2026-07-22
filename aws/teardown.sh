#!/usr/bin/env bash
# Removes the Batch resources and S3 bucket created by this project, so
# you stop paying for anything once you're done. Does NOT remove your IAM
# user or ECR image/repo (delete those manually in the console if wanted).
set -euo pipefail

QUEUE=$(grep -A6 "^aws:" config/config.yaml | grep batch_job_queue | awk '{print $2}' | tr -d '"')
JOBDEF=$(grep -A6 "^aws:" config/config.yaml | grep batch_job_definition | awk '{print $2}' | tr -d '"')
BUCKET=$(grep -A6 "^aws:" config/config.yaml | grep s3_bucket | awk '{print $2}' | tr -d '"')

echo "==> Disabling and deleting job queue"
aws batch update-job-queue --job-queue "${QUEUE}" --state DISABLED || true
sleep 5
aws batch delete-job-queue --job-queue "${QUEUE}" || true

echo "==> Disabling and deleting compute environment"
aws batch update-compute-environment --compute-environment hla-pipeline-ce --state DISABLED || true
sleep 5
aws batch delete-compute-environment --compute-environment hla-pipeline-ce || true

echo "==> Deregistering job definitions"
for rev in $(aws batch describe-job-definitions --job-definition-name "${JOBDEF}" --status ACTIVE --query 'jobDefinitions[].revision' --output text); do
  aws batch deregister-job-definition --job-definition "${JOBDEF}:${rev}" || true
done

echo "==> Emptying and deleting S3 bucket: s3://${BUCKET}"
aws s3 rm "s3://${BUCKET}" --recursive || true
aws s3api delete-bucket --bucket "${BUCKET}" || true

echo "==> Teardown complete."
