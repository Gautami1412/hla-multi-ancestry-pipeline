# AWS setup

This is how I set up AWS for the project, in the order I did it. I used AWS because BWA needs about 6 GB of memory to align and my laptop did not have that free. Fargate bills only while a job is running, so nothing keeps costing money between runs.

## 1. Account and billing

I made an AWS account and set a budget alert in Billing, then Budgets, at $20 so a mistake could not get expensive. New accounts can be restricted. My first new account could not create S3 buckets because of an AWS Organizations policy I had no way to change, so I used an older account of mine instead. If S3 gives `AccessDenied` on a brand-new account, a support case is the way out.

## 2. IAM user and the AWS CLI

I work as an IAM user, not the root account, with access to S3, ECR and Batch. The AWS CLI is installed in Ubuntu (WSL). I install it from `/tmp` because the installer unpacks a folder called `aws`, which would clash with this repo's `aws/` folder:

```bash
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip -q awscliv2.zip && sudo ./aws/install
aws configure          # access key, secret key, region us-east-1, output json
aws sts get-caller-identity
```

## 3. S3 bucket

The bucket name is `aws.s3_bucket` in `config/config.yaml`. Bucket names are global, so it has to be unique.

```bash
bash aws/create_s3_bucket.sh
```

## 4. Reference files and data

From the repo root:

```bash
bash scripts/make_region_bed.sh
bash scripts/download_reference.sh
bash scripts/make_no_alt_reference.sh
bash scripts/download_giab.sh
bash scripts/download_samples.sh
aws s3 sync resources s3://<bucket>/resources
```

`make_no_alt_reference.sh` removes the 261 `*_alt` contigs from the reference. I need this because with them left in, BWA gives HLA-region reads mapping quality 0 and GATK throws them away.

The BWA index for the cleaned reference is built once on AWS, not on my laptop, once the FASTA is in S3:

```bash
bash aws/build_reference_index.sh
```

It takes about an hour and prints a job ID. When the job has `SUCCEEDED`, the index files are in S3 next to the FASTA.

## 5. Docker image

GitHub Actions builds the image and pushes it to GitHub Container Registry and to ECR. It runs when something in `docker/` changes, or by hand: Actions tab, Build Docker image, Run workflow. It needs two repository secrets, `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`, for an IAM user that can only push to ECR.

`docker/build_and_push.sh` does the same thing from a machine that has Docker.

The Snakefile, rules, scripts and config are copied into the image, so I rebuild it after changing any of them. A Batch job always runs whatever is in the image, not what is on my laptop.

## 6. AWS Batch

```bash
bash aws/setup_batch.sh
```

This creates the Fargate compute environment, the job queue and the job definition (4 vCPU, 16 GB memory, 100 GiB temporary disk). The script hides some errors. Once I got "queue already exists, skipping" when the queue had never been created, because the compute environment was not ready yet. I check it afterwards:

```bash
aws batch describe-job-queues --region us-east-1 --query "jobQueues[].[jobQueueName,state,status]" --output table
```

## 7. Running jobs

I run one sample first as a test, then the full cohort:

```bash
bash aws/submit_job.sh results/gvcf/HG001.g.vcf.gz
bash aws/submit_job.sh
```

Each prints a job ID. To see how far a job has got:

```bash
JOB=<job id>
LOG=$(aws batch describe-jobs --jobs $JOB --region us-east-1 --query "jobs[0].container.logStreamName" --output text)
aws logs tail /aws/batch/job --log-stream-names "$LOG" --since 3h --region us-east-1 | grep -E "Error in rule|steps \(|Exiting" | tail -3
```

The job copies `logs/` and `results/` to S3 when it finishes, including when it fails, so I can read the real error afterwards. I download the results with:

```bash
aws s3 sync s3://<bucket>/results results
```

## 8. Cleaning up

`bash aws/teardown.sh` deletes the Batch queue, compute environment and job definition, and empties and deletes the S3 bucket. It does not delete the IAM users or the ECR repository, so I remove those in the console.

## Cost

The first full cohort run took about 2 hours and I estimate $1 to $2 of Fargate compute, plus a few cents of S3 storage. The one-off reference index job adds about an hour of one CPU. I will replace these estimates with the real figures from the billing page.
