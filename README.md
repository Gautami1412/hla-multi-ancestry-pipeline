# HLA Multi-Ancestry Variant Calling Pipeline

I built this project to test whether GATK's standard variant-calling workflow works equally well across ancestries in the HLA region, which is the most diverse and most reference-biased part of the human genome. The pipeline runs the full GATK Best Practices workflow (QC, alignment, base recalibration, variant calling, joint genotyping, filtering, benchmarking) on 1000 Genomes samples from four ancestry superpopulations. The analysis is restricted to the extended HLA locus on chromosome 6, and accuracy is scored against Genome in a Bottle (GIAB) truth sets, separately for each ancestry, so the gap can be measured directly.

The workflow is orchestrated with Snakemake, packaged in a Docker image that GitHub Actions builds and tests, and executed on AWS Batch. This README documents the design, the order I ran things in, what is finished, and what is still in progress

---

## Project status: 

### Finished

- I wrote the full 8-stage Snakemake pipeline. A dry run resolves all ~200 steps with no missing inputs.
- I downloaded and indexed the reference genome (GRCh38 with decoys), dbSNP, the Mills indel set, the GIAB truth sets, and the HLA-region data for all 15 samples (12 from 1000 Genomes and 3 from GIAB).
- I built a Docker image with every tool the pipeline needs. GitHub Actions builds and tests it on each change to ```docker/```, then publishes it to GitHub Container Registry and to AWS ECR.
- I set up AWS: a private S3 bucket (about 11.8 GiB of reference data and samples uploaded), an ECR repository, and an AWS Batch environment on Fargate with a job queue and job definition (4 vCPU, 16 GB memory, 100 GB temporary disk).
- I tested on one sample (alignment, then recalibration and variant calling) before launching the full cohort.
- The full-cohort run on AWS Batch completed 195 of 200 steps. That covers region extraction, QC, alignment, duplicate marking, recalibration, variant calling, joint genotyping, and hard filtering for all 15 samples. The final filtered cohort VCF exists.

### In progress

The last stage, hap.py benchmarking, stopped on an argument error: hap.py's ```--stratification``` option expects one table file, and I passed it a comma-separated list of region files. I identified the fix (a small ```strat.tsv``` listing the stratification files) and am applying it, then rerunning.

### Results

Final accuracy numbers (precision, recall, F1 per ancestry) are pending the benchmarking rerun. I have not drawn any conclusions about accuracy yet.
One finding already stands: GIAB truth sets cover only 2 of my 4 ancestry groups (see section 4).

---

## 1. What each tool is actually for here

**Snakemake** is the workflow engine. Running 8 tools in the right order for 15 samples by hand means 120+ commands, and it is easy to run something out of order or forget which files are out of date. Instead, I describe each step once as a rule ("this command turns file A into file B"). Snakemake works out the dependency graph, runs independent steps in parallel, and skips anything already up to date. The ```rules/*.smk``` files are the pipeline stages, and ```Snakefile``` ties them together.

**Docker** removes the "it works on my machine" problem. GATK, BWA, samtools, hap.py and the rest need specific versions and can be difficult to install together. ```docker/Dockerfile``` builds a single image with all of them pinned, plus the pipeline code, so the pipeline runs the same way on a laptop, a colleague's machine, or the cloud.``` hap.py``` needs an old Python (2.7), so it lives in its own environment inside the image, reached through a small launcher script.

**GitHub Actions** builds the image. My laptop does not have enough memory to build and test it reliably, so ```.github/workflows/docker.yml``` builds it on GitHub's computers, checks that Snakemake and GATK run inside it, and pushes it to the registries.

**AWS** supplies the memory my laptop lacks. BWA needs about 6 GB for the genome index, and my laptop had less than that available. S3 stores the data and results, ECR stores the image, IAM controls permissions, and Batch on Fargate runs the job on rented computers that exist only while the job runs.

---

## 2. Repo layout

```
hla-multi-ancestry-pipeline/
├── Snakefile                  # entry point, wires up all 8 stages
├── config/config.yaml         # all tunable parameters
├── samples.tsv                # cohort: AFR/EUR/SAS/EAS samples
├── giab_samples.tsv           # GIAB truth-set samples (HG001/HG002/HG005)
├── rules/                     # one .smk file per pipeline stage
│   ├── 00_reference.smk       #   reference indexing
│   ├── 01_extract_region.smk  #   slice HLA region from CRAM -> FASTQ
│   ├── 02_qc.smk              #   FastQC, fastp, MultiQC
│   ├── 03_align.smk           #   BWA-MEM, sort, MarkDuplicates
│   ├── 04_bqsr.smk            #   BaseRecalibrator, ApplyBQSR
│   ├── 05_call_variants.smk   #   HaplotypeCaller (GVCF mode)
│   ├── 06_joint_genotype.smk  #   CombineGVCFs, GenotypeGVCFs
│   ├── 07_filter.smk          #   GATK hard filters
│   └── 08_benchmark.smk       #   hap.py vs GIAB, per ancestry
├── envs/                      # conda environments for non-Docker runs
├── scripts/                   # download + helper scripts, aggregation
├── docker/                    # Dockerfile + environment.yml
├── aws/                       # S3, Batch, and job-submission scripts
└── .github/workflows/         # GitHub Actions: Docker image build and test
```

```resources/```, ```results/```, ```logs/``` and ```benchmarks/``` are created by the scripts and the pipeline. They are gitignored because they hold multi-GB genomic files that do not belong in version control.

---

## 3. Why the analysis is restricted to HLA, and why I slice samples from CRAMs

Whole-genome alignment of 15 samples is a multi-day, many-CPU job. The question I care about concerns the HLA region, so stage 1 pulls only the extended HLA interval (chr6:28,510,120-33,480,577, GRCh38) from each sample's public, already-aligned CRAM file and converts those reads back to FASTQ. From there, the pipeline (QC, trimming, re-alignment, recalibration, calling) runs exactly as it would on whole-genome data, at roughly 1/500th of the size. This is a standard approach for regional re-analysis. It is a compute-feasibility choice, and it is not the same as a full whole-genome clinical pipeline.

I align to the full GRCh38 reference with decoy sequences, not to an HLA-only reference. HLA genes resemble each other closely, so a small reference would force reads into the wrong places and make the benchmark look better or worse than it should. A full reference gives those reads somewhere else to go.

---

## 4.The reference-bias gap

GIAB truth sets (hand-curated gold-standard variant calls) exist for only a handful of individuals: HG001/NA12878 (European), the HG002-004 Ashkenazi trio, and HG005-007 (Han Chinese). No GIAB truth set exists for African or South Asian ancestry. Consequences for this project:

- HG001 (EUR) and HG005 (EAS) in ```giab_samples.tsv``` can be scored for precision, recall and F1 in stage 8.
- HG002 is included as an Ashkenazi, European-adjacent proxy. It is not a substitute for African or South Asian truth.
- The African and South Asian samples in ```samples.tsv``` go through the same pipeline, but cannot be benchmarked against ground truth because none exists. ```scripts/aggregate_benchmark.py``` records them explicitly as ```has_truth_set=False``` rows instead of omitting them.

That absence is the first half of the finding. The second half is the precision and recall gap, if any, between HG001 (EUR) and HG005 (EAS) once stage 8 completes. With one scored sample per ancestry, any gap I see suggests a pattern but doesn't prove one.

---

## 5. Execution order

All commands were run from the repository root.

One-time setup (data)
```bash
bash scripts/make_region_bed.sh          # writes resources/regions/hla_extended.bed
bash scripts/download_reference.sh       # GRCh38 FASTA, BWA index, dbSNP, Mills indels
bash scripts/download_giab.sh            # GIAB truth VCFs, confident BEDs, stratification BEDs
bash scripts/verify_urls.sh              # check sample URLs resolve before the big download
bash scripts/download_samples.sh         # slices the HLA region from each sample's CRAM
```

Check the dependency graph before spending compute
```bash
snakemake -n --cores 4
```

Local run with conda environments (needs about 6 GB free memory for alignment)
```bash
snakemake --cores 8 --use-conda
```

Local run inside Docker
```bash
docker build -t hla-pipeline:latest -f docker/Dockerfile .
docker run --rm -v $(pwd):/work -w /work hla-pipeline:latest \
    snakemake --cores 8 --use-conda
```
The image already contains the tools, so ```--use-conda``` is not needed here.

AWS Batch run
```bash
bash docker/build_and_push.sh
bash aws/create_s3_bucket.sh
bash aws/setup_batch.sh
bash aws/submit_job.sh all
```

Final outputs:
- ```results/qc/multiqc_report.html```: aggregated QC across all samples
- ```results/filtered/cohort.filtered.vcf.gz```: the joint-called, hard-filtered cohort VCF
- ```results/benchmark/ancestry_stratified_report.tsv```: precision, recall and F1 per ancestry, plus the samples with no truth set

## 6. How I built it, in phases

I worked in phases because genomics pipelines fail in ways that are much easier to isolate one stage at a time.

- **Scaffold and dry run**: I checked that paths and wildcards were consistent and used snakemake -n to confirm the dependency graph resolved.
- **Real data**: I verified every download URL, corrected the ones that had moved, and added retries, timeouts and resume to the download scripts.
- **One sample end to end**: I did not run the full cohort until a single sample worked.
- **Local compute attempt**: Alignment ran out of memory on my laptop, which is what pushed the work to the cloud.
- **Containerization**: I wrote the Dockerfile, then moved the build to GitHub Actions and added tool checks to it.
- **AWS**: I set up storage, the registry, and Batch, and tested one sample on the cloud before running the cohort.
- **Full cohort run**: The run reached 195 of 200 steps. Benchmarking is the remaining stage.
- **Write-up**: This happens once the benchmarking results exist.

---

## 7. Problems I hit and how I fixed them

| Problem | How I diagnosed it | Fix |
|---|---|---|
| Dry run failed on missing `.fai` and `.dict` files | GATK and samtools need these beside the reference, but my rules never declared them as inputs, so Snakemake did not build them first | Added them as explicit rule inputs |
| Corrupted region BED file | The script searched for `end` and also matched it inside "HLA_extended" | Anchored the search to the exact config keys |
| Downloads stalled or reset | Public servers drop long connections | Added retries, resume (`curl -C -`), timeouts, and skip-if-already-downloaded |
| Sample and GIAB URLs returned 404 | Public indexes had been reorganized | Looked up current locations and updated the sample sheets |
| Disk space ran out on the system drive | WSL was storing its disk there | Moved the Linux environment to a larger drive |
| BWA killed for lack of memory | The genome index needs about 6 GB and my laptop had less | Moved the compute stages to AWS Batch |
| The container had the tools but not my pipeline code | I read the job scripts before running them and saw nothing copied the Snakefile and rules in | Added `COPY` steps to the Dockerfile |
| Cloud job too small | Reference files exceed the default 20 GB job disk, and BWA is tight at 8 GB | Raised the job to 16 GB memory and a 100 GB temporary disk |
| Batch setup reported "queue already exists" when it did not | The script hides errors, and the queue failed because the compute environment was not ready yet | Checked each resource directly and created the queue by hand |
| Recalibration failed with no visible reason | The real error was in a log file that disappeared with the container | Changed the job to copy logs to S3 even on failure, then read the error |
| `Invalid GZIP header` on the dbSNP index | Both data files passed `gzip -t`, but the dbSNP index failed. The deeper cause was that the dbSNP file was gzip, not BGZF, which GATK needs for random access | Recompressed with `bgzip`, rebuilt the index with `tabix`, re-uploaded |
| `hap.py: command not found` in the cloud job | hap.py had been left out of the image's main environment because it needs Python 2.7 | Installed it in its own environment in the image with a launcher, and added a version check to the build |
| hap.py failed on `--stratification` | It expects a table file, and I gave it a comma-separated list | Creating a small `strat.tsv` and pointing the config at it (in progress) |

---

## 8. Known simplifications

- Hard filters, not VQSR. VQSR needs a much larger cohort than 15 samples to train on. I used GATK's documented hard-filter thresholds (```config.yaml > hard_filters```). VQSR is the production-scale path.
- CombineGVCFs, not GenomicsDBImport. This is fine at this cohort size. GenomicsDBImport is the scale-up alternative for hundreds of samples.
- Region-sliced CRAMs, not raw whole-genome FASTQ. See section 3. I chose this for compute feasibility.
- hap.py, not RTG vcfeval. Both are standard. I chose hap.py for its built-in support for GIAB stratification files.
- One scored sample per ancestry. HG001 for European and HG005 for East Asian, so results are suggestive and not statistically conclusive.

---

## 9. Cost and time

- Local run with conda or Docker on 12-15 samples restricted to HLA: a few hours on a modern laptop, dominated by BWA alignment and HaplotypeCaller, provided about 6 GB of memory is available for alignment.
- AWS Batch (Fargate): the full cohort ran in roughly two hours at 4 vCPU and 16 GB, which comes to an estimated one to two dollars of compute, plus a few cents of S3 storage. I will replace this estimate with the actual cost from the billing page.
- The one-time reference downloads total a few GB and are kept in S3, so they are not repeated for each run.
