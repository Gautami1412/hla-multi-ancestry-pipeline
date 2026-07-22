# HLA Multi-Ancestry Variant Calling Pipeline

Does GATK's standard variant-calling pipeline work equally well across
ancestries in the HLA region — the most diverse, most reference-biased
part of the human genome? This repo runs the full GATK Best Practices
workflow (QC → align → BQSR → call → joint genotype → filter → benchmark)
on 1000 Genomes samples from four ancestry superpopulations, restricted to
the extended HLA locus on chr6, and scores accuracy against GIAB truth
sets — separately per ancestry — to measure the gap directly.

This README assumes you've never used Snakemake, Docker, or AWS. Read it
top to bottom once before running anything.

---

## 1. What each tool is actually for here

**Snakemake** is the workflow engine. Instead of you manually running 8
tools in the right order for 15 samples (120+ commands, easy to mess up
or forget which files are stale), you describe each step once as a
*rule* — "this command turns file A into file B" — and Snakemake figures
out the dependency graph, runs steps in parallel where possible, and
skips anything already up to date. The `rules/*.smk` files in this repo
are the 8 pipeline stages; `Snakefile` wires them together.

**Docker** solves "it works on my machine." GATK, BWA, samtools, hap.py
etc. all need specific versions and can be a pain to install correctly.
`docker/Dockerfile` builds one image with everything pinned and working,
so the pipeline runs identically on your laptop, a colleague's laptop,
or in the cloud.

**AWS** is only for when your laptop isn't enough — either compute
(alignment/calling is CPU-heavy) or you want a run you can point
someone else at without them installing anything. Everything in this
project works fully locally first; AWS is optional and additive.

**Claude Code** (which you already have in VS Code) is how you'll
actually *drive* all of this — see §6 below for the specific prompts to
give it at each phase, rather than typing every command by hand.

---

## 2. Repo layout

```
hla-multi-ancestry-pipeline/
├── Snakefile                  # entry point, wires up all 8 stages
├── config/config.yaml         # all tunable parameters live here
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
├── envs/                      # conda environments (local, non-Docker runs)
├── scripts/                   # download + helper scripts, aggregation
├── docker/                    # Dockerfile + build/push script
└── aws/                       # SETUP.md + S3/Batch automation scripts
```

`resources/`, `results/`, `logs/`, `benchmarks/` are created by the
scripts/pipeline itself and are gitignored — they hold multi-GB genomic
files that shouldn't go in version control.

---

## 3. Why the region is restricted to HLA (and why samples get sliced from CRAMs)

Full whole-genome alignment of even 12 samples is a multi-day, many-CPU
job — not a reasonable demo. Since the actual question is about the HLA
region specifically, stage 1 pulls only the extended HLA interval
(chr6:28,510,120-33,480,577, GRCh38) out of each sample's publicly
hosted, already-aligned 1000 Genomes high-coverage CRAM, converts that
back to FASTQ, and the rest of the pipeline (QC → trim → realign → BQSR
→ call) runs on that exactly as it would on whole-genome data — just at
~1/500th the size. This is a standard approach for regional re-analysis
and is called out here so it isn't mistaken for full WGS best practices.

---

## 4. The reference-bias gap, spelled out before you run anything

GIAB "truth" (gold-standard, hand-curated) VCFs exist for only a handful
of individuals: HG001/NA12878 (European), the HG002-004 Ashkenazi trio,
and HG005-007 (Han Chinese). **There is no GIAB truth set for African or
South Asian ancestry.** That means:

- HG001 (EUR) and HG005 (EAS) in `giab_samples.tsv` can be scored for
  precision/recall/F1 in stage 8.
- HG002 is included as an Ashkenazi/European-adjacent proxy, not a
  substitute for AFR/SAS truth.
- The AFR and SAS samples in `samples.tsv` go through the *entire*
  pipeline identically, but **cannot be benchmarked against ground
  truth at all** — because none exists. `scripts/aggregate_benchmark.py`
  records this explicitly as `has_truth_set=False` rows rather than
  silently omitting them.

That absence is not a bug to fix — it's the first half of the finding.
The second half is whatever recall/precision gap shows up between HG001
(EUR) and HG005 (EAS) once you run stage 8.

---

## 5. Execution order

Run everything from the repo root.

```bash
# One-time setup
bash scripts/make_region_bed.sh          # writes resources/regions/hla_extended.bed
bash scripts/download_reference.sh       # GRCh38 FASTA, dbSNP, Mills indels (~3-4 GB)
bash scripts/download_giab.sh            # GIAB truth VCFs + confident BEDs + stratification BEDs
bash scripts/verify_urls.sh              # check sample URLs resolve BEFORE the big download
bash scripts/download_samples.sh         # slices HLA region from each sample's CRAM

# Sanity-check the DAG before spending any compute
snakemake -n --cores 4

# Local run (conda-managed environments, defined in envs/)
snakemake --cores 8 --use-conda

# OR: local run inside Docker (no conda install needed)
docker build -t hla-pipeline:latest -f docker/Dockerfile .
docker run --rm -v $(pwd):/work -w /work hla-pipeline:latest \
    snakemake --cores 8 --use-conda

# OR: AWS (see aws/SETUP.md first — one-time account setup)
bash docker/build_and_push.sh
bash aws/create_s3_bucket.sh
bash aws/setup_batch.sh
bash aws/submit_job.sh all
```

Final outputs:
- `results/qc/multiqc_report.html` — aggregated QC across all samples
- `results/filtered/cohort.filtered.vcf.gz` — joint-called, hard-filtered cohort VCF
- `results/benchmark/ancestry_stratified_report.tsv` — the actual finding: precision/recall/F1 per ancestry, plus which samples had no truth set at all

---

## 6. How to actually drive this with Claude Code in VS Code

Open this folder in VS Code, open the Claude Code panel, and work
through it in phases rather than asking for everything at once —
genomics pipelines fail in ways that are much easier to debug one stage
at a time.

**Phase 1 — verify the scaffold and fill gaps.**
> "Read through the Snakefile and rules/*.smk in this repo. Check the
> file paths and wildcards are internally consistent, and run
> `snakemake -n --cores 4` to dry-run the DAG. Fix anything that's
> broken."

**Phase 2 — get real data flowing.**
> "Run scripts/verify_urls.sh. For any FAIL rows, look up the correct
> current URL on the 1000 Genomes / GIAB FTP index (linked in the
> script's error output) and fix samples.tsv or giab_samples.tsv."

**Phase 3 — run one sample end to end first.**
> "Before running the full cohort, get just HG00096 through stages 1-7
> (`snakemake --cores 4 --use-conda results/dedup/HG00096.dedup.bam` then
> extend the target one stage at a time). Show me each stage's log if
> anything fails."

**Phase 4 — scale to the full cohort.**
> "Now run `snakemake --cores 8 --use-conda` for the full target list in
> `rule all`. Monitor for failures and summarize any errors."

**Phase 5 — Docker parity check.**
> "Build the Docker image from docker/Dockerfile and re-run the dry run
> (`snakemake -n`) inside the container to confirm it matches the conda
> run."

**Phase 6 — AWS (optional, once local works end-to-end).**
> "Walk me through aws/SETUP.md step by step, pausing after each AWS CLI
> command so I can confirm it in the console before continuing."

**Phase 7 — the write-up.**
> "Read results/benchmark/ancestry_stratified_report.tsv and summarize:
> which ancestry groups had a matched GIAB truth set, what precision/
> recall/F1 looked like for HG001 vs HG005, and what the complete
> absence of AFR/SAS truth data means for interpreting this result.
> Draft that as the reference-bias findings section."

Keep each Claude Code session scoped to one phase — it makes failures
easier to isolate and keeps the diffs reviewable.

---

## 7. Known simplifications (say these out loud in your write-up)

- **Hard filters, not VQSR.** GATK's Variant Quality Score Recalibration
  needs a much larger cohort than 12-15 samples to train on. This repo
  uses GATK's documented hard-filter thresholds instead
  (`config.yaml > hard_filters`); VQSR is the production-scale path.
- **CombineGVCFs, not GenomicsDBImport.** Fine at this cohort size;
  GenomicsDBImport is the scale-up alternative for hundreds+ of samples.
- **Region-sliced CRAMs, not raw WGS FASTQ.** See §3 — chosen for
  compute feasibility, not because it's how you'd run this in production.
- **hap.py, not RTG vcfeval.** Either is standard; hap.py was chosen for
  the built-in GIAB stratification-BED support.
- **Sample list is illustrative.** The exact ENA run accessions in
  `samples.tsv` should be re-verified against the current 1000 Genomes
  index (`scripts/verify_urls.sh`) — these indexes get reorganized.

---

## 8. Cost and time expectations

- Local (conda or Docker), 12-15 samples restricted to HLA: a few hours
  on a modern laptop, dominated by BWA alignment and HaplotypeCaller.
- AWS Fargate Batch: low single-digit dollars for a full cohort run,
  plus a few cents of S3 storage. See `aws/SETUP.md > Cost expectations`.
- The one-time reference/dbSNP/Mills/GIAB downloads are a few GB total —
  do this once, not per run.
