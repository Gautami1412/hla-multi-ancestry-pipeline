"""
HLA Multi-Ancestry Variant Calling Pipeline
=============================================
Entry point. Reads config/config.yaml + samples.tsv, wires together the
8 pipeline stages as separate rule files under rules/, and defines the
final targets (per-ancestry hap.py benchmark reports).

Run with:
    snakemake -n                        # dry run, sanity check the DAG
    snakemake --cores 8 --use-conda     # local execution
    snakemake --cores 8 --use-singularity --singularity-args "--bind $PWD"  # container execution

See README.md for the full walkthrough.
"""
import pandas as pd

configfile: "config/config.yaml"

samples_df = pd.read_csv(config["sample_sheet"], sep="\t", dtype=str, comment="#")
giab_df = pd.read_csv("giab_samples.tsv", sep="\t", dtype=str, comment="#")

COHORT_SAMPLES = list(samples_df["sample"])
GIAB_SAMPLES = list(giab_df["sample"])
# GIAB samples flow through the SAME alignment/calling/filtering rules as
# the cohort (identical wildcard 'sample'), so SAMPLES = union of both.
SAMPLES = COHORT_SAMPLES + GIAB_SAMPLES

ANCESTRY_OF = dict(zip(samples_df["sample"], samples_df["ancestry"]))
ANCESTRY_OF.update(dict(zip(giab_df["sample"], giab_df["ancestry"])))
CRAM_URL_OF = dict(zip(samples_df["sample"], samples_df["source_cram_url"]))
CRAM_URL_OF.update(dict(zip(giab_df["sample"], giab_df["source_cram_url"])))

ANCESTRY_GROUPS = config["ancestry_groups"]

RESULTS = config["paths"]["results"]
LOGS = config["paths"]["logs"]
BENCH = config["paths"]["benchmarks"]

# Reference + its samtools/GATK sidecar indexes. Every GATK tool (-R) and
# `samtools view -T` require the .fai and sequence .dict to sit beside the
# FASTA, so downstream rules declare them explicitly (built by the
# fasta_faidx / fasta_dict rules in rules/00_reference.smk).
REF = config["reference"]["fasta"]
REF_FAI = REF + ".fai"
REF_DICT = REF.replace(".fa", ".dict")

wildcard_constraints:
    sample = "|".join(SAMPLES),
    ancestry = "|".join(ANCESTRY_GROUPS),

include: "rules/00_reference.smk"
include: "rules/01_extract_region.smk"
include: "rules/02_qc.smk"
include: "rules/03_align.smk"
include: "rules/04_bqsr.smk"
include: "rules/05_call_variants.smk"
include: "rules/06_joint_genotype.smk"
include: "rules/07_filter.smk"
include: "rules/08_benchmark.smk"


def happy_targets(wildcards):
    """Only GIAB samples have a matched truth set — hap.py can only score
    those. The AFR and SAS cohort samples have NO truth set at all; that
    absence is itself part of the reference-bias finding (see README)."""
    return [f"{RESULTS}/benchmark/{gsample}/{gsample}.summary.csv" for gsample in GIAB_SAMPLES]


rule all:
    input:
        f"{RESULTS}/qc/multiqc_report.html",
        expand(f"{RESULTS}/filtered/cohort.filtered.vcf.gz"),
        happy_targets,
        f"{RESULTS}/benchmark/ancestry_stratified_report.tsv",
