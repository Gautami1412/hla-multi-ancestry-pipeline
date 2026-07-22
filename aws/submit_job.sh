#!/usr/bin/env bash
# Submits one Batch job that runs Snakemake inside the container, syncing
# resources/ and results/ to/from S3 before and after.
# Usage: bash aws/submit_job.sh [snakemake-target]   (default target: 'all')
set -euo pipefail

TARGET="${1:-all}"
AWS_REGION=$(grep -A2 "^aws:" config/config.yaml | grep region | awk '{print $2}' | tr -d '"')
QUEUE=$(grep -A6 "^aws:" config/config.yaml | grep batch_job_queue | awk '{print $2}' | tr -d '"')
JOBDEF=$(grep -A6 "^aws:" config/config.yaml | grep batch_job_definition | awk '{print $2}' | tr -d '"')
BUCKET=$(grep -A6 "^aws:" config/config.yaml | grep s3_bucket | awk '{print $2}' | tr -d '"')

CMD="aws s3 sync s3://${BUCKET}/resources /work/resources && \
     snakemake --cores 4 --use-conda ${TARGET} && \
     aws s3 sync /work/results s3://${BUCKET}/results"

echo "==> Submitting job: target=${TARGET}"
aws batch submit-job \
  --job-name "hla-pipeline-$(date +%s)" \
  --job-queue "${QUEUE}" \
  --job-definition "${JOBDEF}" \
  --container-overrides "command=[\"bash\",\"-lc\",\"${CMD}\"]" \
  --region "${AWS_REGION}"

echo "==> Track status with:"
echo "aws batch list-jobs --job-queue ${QUEUE} --region ${AWS_REGION}"
