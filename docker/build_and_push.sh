#!/usr/bin/env bash
# Build the pipeline image and push it to your AWS ECR repo, so AWS Batch
# jobs can pull it. Run this from the repo root:
#   bash docker/build_and_push.sh
set -euo pipefail

AWS_REGION=$(grep -A2 "^aws:" config/config.yaml | grep region | awk '{print $2}' | tr -d '"')
ECR_REPO=$(grep -A6 "^aws:" config/config.yaml | grep ecr_repo | awk '{print $2}' | tr -d '"')
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

if [ -z "$ACCOUNT_ID" ]; then
  echo "Could not determine AWS account ID. Run 'aws configure' first." >&2
  exit 1
fi

ECR_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"

echo "==> Creating ECR repo (if it doesn't exist yet): ${ECR_REPO}"
aws ecr describe-repositories --repository-names "${ECR_REPO}" --region "${AWS_REGION}" \
  >/dev/null 2>&1 || aws ecr create-repository --repository-name "${ECR_REPO}" --region "${AWS_REGION}"

echo "==> Logging in to ECR"
aws ecr get-login-password --region "${AWS_REGION}" \
  | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "==> Building image"
docker build -t "${ECR_REPO}:latest" -f docker/Dockerfile .

echo "==> Tagging + pushing to ${ECR_URI}:latest"
docker tag "${ECR_REPO}:latest" "${ECR_URI}:latest"
docker push "${ECR_URI}:latest"

echo "==> Done. Image URI (needed by aws/register_batch_job.sh):"
echo "${ECR_URI}:latest"
