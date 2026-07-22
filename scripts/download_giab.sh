#!/usr/bin/env bash
# Downloads GIAB v4.2.1 truth VCFs + confident-region BEDs for HG001,
# HG002, HG005 (the samples listed in giab_samples.tsv), plus the
# stratification BED files (low-complexity, segdup) used for the
# "difficult region" breakdown in stage 8.
set -euo pipefail

OUTDIR="resources/giab"
mkdir -p "$OUTDIR/stratification"

NIST="https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release"

declare -A PATHS=(
  [HG001]="NA12878_HG001/NISTv4.2.1/GRCh38"
  [HG002]="AshkenazimTrio/HG002_NA24385_son/NISTv4.2.1/GRCh38"
  [HG005]="ChineseTrio/HG005_NA24631_son/NISTv4.2.1/GRCh38"
)

for sample in "${!PATHS[@]}"; do
  path="${PATHS[$sample]}"
  echo "==> ${sample}"
  curl -L -o "${OUTDIR}/${sample}_GRCh38_1_22_v4.2.1_benchmark.vcf.gz" \
    "${NIST}/${path}/${sample}_GRCh38_1_22_v4.2.1_benchmark.vcf.gz"
  curl -L -o "${OUTDIR}/${sample}_GRCh38_1_22_v4.2.1_benchmark.vcf.gz.tbi" \
    "${NIST}/${path}/${sample}_GRCh38_1_22_v4.2.1_benchmark.vcf.gz.tbi"
  curl -L -o "${OUTDIR}/${sample}_GRCh38_1_22_v4.2.1_benchmark_noinconsistent.bed" \
    "${NIST}/${path}/${sample}_GRCh38_1_22_v4.2.1_benchmark_noinconsistent.bed"
done

echo "==> GIAB stratification BEDs (low-complexity, segdup)"
STRAT="https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/genome-stratifications/v3.1"
curl -L -o "${OUTDIR}/stratification/LowComplexity.bed.gz" \
  "${STRAT}/GRCh38/LowComplexity/GRCh38_AllTandemRepeatsandHomopolymers_slop5.bed.gz" || true
curl -L -o "${OUTDIR}/stratification/SegmentalDuplications.bed.gz" \
  "${STRAT}/GRCh38/SegmentalDuplications/GRCh38_segdups.bed.gz" || true

echo "==> Done."
ls -lh "$OUTDIR"

echo ""
echo "NOTE: NIST reorganizes the GIAB FTP layout periodically. If a curl"
echo "above 404s, browse the current tree at:"
echo "https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/"
echo ""
echo "REMINDER: there is no AFR or SAS entry above — GIAB has no truth set"
echo "for those ancestries. That's expected, not a bug in this script."
