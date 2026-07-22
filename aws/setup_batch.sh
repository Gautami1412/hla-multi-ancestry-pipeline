#!/usr/bin/env bash
# Creates a minimal Fargate-based AWS Batch setup: IAM execution role,
# compute environment, job queue, and job definition pointing at the
# image you pushed with docker/build_and_push.sh.
# Run from repo root: bash aws/setup_batch.sh
set -euo pipefail

AWS_REGION=$(grep -A2 "^aws:" config/config.yaml | grep region | awk '{print $2}' | tr -d '"')
QUEUE=$(grep -A6 "^aws:" config/config.yaml | grep batch_job_queue | awk '{print $2}' | tr -d '"')
JOBDEF=$(grep -A6 "^aws:" config/config.yaml | grep batch_job_definition | awk '{print $2}' | tr -d '"')
ECR_REPO=$(grep -A6 "^aws:" config/config.yaml | grep ecr_repo | awk '{print $2}' | tr -d '"')
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
IMAGE_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:latest"

echo "==> Creating Batch execution IAM role (if missing)"
ROLE_NAME="hla-pipeline-batch-execution-role"
if ! aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  aws iam create-role --role-name "$ROLE_NAME" \
    --assume-role-policy-document '{
      "Version": "2012-10-17",
      "Statement": [{"Effect": "Allow", "Principal": {"Service": "ecs-tasks.amazonaws.com"}, "Action": "sts:AssumeRole"}]
    }'
  aws iam attach-role-policy --role-name "$ROLE_NAME" \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
  aws iam attach-role-policy --role-name "$ROLE_NAME" \
    --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
fi
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

echo "==> Getting default VPC subnets + security group"
VPC_ID=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)
SUBNETS=$(aws ec2 describe-subnets --filters Name=vpc-id,Values="$VPC_ID" --query 'Subnets[].SubnetId' --output json)
SG_ID=$(aws ec2 describe-security-groups --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values=default --query 'SecurityGroups[0].GroupId' --output text)

echo "==> Creating Fargate compute environment"
aws batch create-compute-environment \
  --compute-environment-name hla-pipeline-ce \
  --type MANAGED \
  --state ENABLED \
  --compute-resources "type=FARGATE,maxvCpus=16,subnets=${SUBNETS},securityGroupIds=[\"${SG_ID}\"]" \
  2>/dev/null || echo "  (compute environment already exists, skipping)"

echo "==> Creating job queue: ${QUEUE}"
aws batch create-job-queue \
  --job-queue-name "${QUEUE}" \
  --state ENABLED \
  --priority 1 \
  --compute-environment-order order=1,computeEnvironment=hla-pipeline-ce \
  2>/dev/null || echo "  (job queue already exists, skipping)"

echo "==> Registering job definition: ${JOBDEF}"
aws batch register-job-definition \
  --job-definition-name "${JOBDEF}" \
  --type container \
  --platform-capabilities FARGATE \
  --container-properties "{
    \"image\": \"${IMAGE_URI}\",
    \"resourceRequirements\": [{\"type\":\"VCPU\",\"value\":\"4\"},{\"type\":\"MEMORY\",\"value\":\"8192\"}],
    \"executionRoleArn\": \"${ROLE_ARN}\",
    \"jobRoleArn\": \"${ROLE_ARN}\",
    \"networkConfiguration\": {\"assignPublicIp\": \"ENABLED\"}
  }" > /dev/null

echo "==> Batch setup complete: queue=${QUEUE} jobdef=${JOBDEF}"
