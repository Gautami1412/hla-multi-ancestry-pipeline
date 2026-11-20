#!/usr/bin/env bash
# Builds the BWA index, .fai and .dict for the no-alt reference as a one-off
# AWS Batch job, and saves them next to the FASTA in S3. I do this on AWS
# because BWA needs about 6 GB of memory and runs on one CPU for about an hour.
#
# Run from the repo root once the FASTA is in S3:
#   bash aws/build_reference_index.sh
set -euo pipefail

AWS_REGION=$(grep -A2 "^aws:" config/config.yaml | grep region | awk '{print $2}' | tr -d '"')
QUEUE=$(grep -A6 "^aws:" config/config.yaml | grep batch_job_queue | awk '{print $2}' | tr -d '"')
JOBDEF=$(grep -A6 "^aws:" config/config.yaml | grep batch_job_definition | awk '{print $2}' | tr -d '"')
BUCKET=$(grep -A6 "^aws:" config/config.yaml | grep s3_bucket | awk '{print $2}' | tr -d '"')

export BUCKET
export NAME="GRCh38_no_alt_plus_decoy_hla"

# Write the container command to a JSON file (avoids shell quoting problems).
python3 - <<'EOF'
import json, os
b, n = os.environ["BUCKET"], os.environ["NAME"]
cmd = f"""set -e
mkdir -p /work/t && cd /work/t
aws s3 cp s3://{b}/resources/reference/{n}.fa .
bwa index {n}.fa
samtools faidx {n}.fa
gatk CreateSequenceDictionary -R {n}.fa -O {n}.dict
aws s3 cp . s3://{b}/resources/reference/ --recursive --exclude "*" --include "{n}.*" --exclude "{n}.fa"
echo DONE_INDEX"""
json.dump({"command": ["bash", "-c", cmd]}, open("/tmp/index_job.json", "w"))
EOF

aws batch submit-job \
  --job-name "index-ref-$(date +%s)" \
  --job-queue "${QUEUE}" \
  --job-definition "${JOBDEF}" \
  --container-overrides file:///tmp/index_job.json \
  --region "${AWS_REGION}" \
  --query jobId --output text
