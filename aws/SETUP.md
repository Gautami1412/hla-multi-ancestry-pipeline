# AWS setup (first time, from zero)

You don't need AWS for stages 1-8 to run — everything above works fully
locally with Docker or conda. AWS is only for when your laptop can't keep
up, or you want a repeatable, sharable cloud run. Do this section last.

## 1. Create an account and lock down billing

1. Go to https://aws.amazon.com and create an account (needs a credit
   card, but everything in this project fits comfortably in the AWS Free
   Tier plus a few dollars of Batch compute time).
2. Immediately set a budget alarm so you can't get surprised:
   - Console → Billing → Budgets → Create budget → "Cost budget" →
     set a monthly amount (e.g. $20) → add your email as an alert at 80%
     and 100%.
3. Do not use your root account for day-to-day work. Create an IAM user:
   - Console → IAM → Users → Create user → name it e.g. `hla-pipeline` →
     attach policies directly: `AmazonS3FullAccess`, `AmazonEC2ContainerRegistryFullAccess`,
     `AWSBatchFullAccess`, `IAMReadOnlyAccess` (scope these down later —
     these are demo-friendly, not least-privilege).
   - Create an access key for this user (IAM → Users → your user →
     Security credentials → Create access key → "Command Line Interface").

## 2. Install and configure the AWS CLI locally

```bash
# macOS
brew install awscli
# or Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip awscliv2.zip && sudo ./aws/install

aws configure
# AWS Access Key ID: <paste>
# AWS Secret Access Key: <paste>
# Default region name: us-east-1   (or whatever you set in config/config.yaml)
# Default output format: json
```

Verify it works:
```bash
aws sts get-caller-identity
```

## 3. Create the S3 bucket (stores reference files + results)

Edit `config/config.yaml` → `aws.s3_bucket` to something globally unique,
e.g. `hla-pipeline-yourname-2026`, then:

```bash
bash aws/create_s3_bucket.sh
```

## 4. Build and push the Docker image to ECR

```bash
bash docker/build_and_push.sh
```

## 5. Set up AWS Batch (compute environment, queue, job definition)

```bash
bash aws/setup_batch.sh
```

This creates a Fargate-based Batch compute environment (no EC2 instances
to manage or forget to shut down — Fargate only bills while a job runs).

## 6. Submit a job

```bash
bash aws/submit_job.sh <snakemake-rule-or-target>
```

## 7. Tear down when done (avoid ongoing charges)

```bash
bash aws/teardown.sh
```

This deletes the Batch compute environment/queue/job definition and
empties+deletes the S3 bucket. It does NOT delete your IAM user or ECR
image — remove those manually in the console if you want a full wipe.

## Cost expectations

Because everything is restricted to the HLA region (~5 Mb) rather than
whole-genome, expect this to cost low single-digit dollars in Batch
Fargate compute for a full 12-15 sample cohort run, plus a few cents of
S3 storage. The reference/dbSNP/Mills downloads are the biggest one-time
transfer (a few GB) — do that once and keep it in S3, not repeatedly.
