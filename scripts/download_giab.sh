#!/usr/bin/env bash
# Downloads the GIAB v4.2.1 truth VCFs and confident-region BEDs for HG001,
# HG002 and HG005 (the samples in giab_samples.tsv), plus the low-complexity
# and segmental-duplication BED files used for the "difficult regions"
# breakdown in stage 8, and the strat.tsv table that hap.py needs for them.
set -euo pipefail

OUTDIR="resources/giab"
mkdir -p "$OUTDIR/stratification"

NIST="https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release"

# Download a file unless it is already there, and retry if the connection drops.
fetch() {
  local out="$1" url="$2"
  if [[ -s "$out" ]]; then
    echo "already have $out"
    return 0
  fi
  curl -L --fail --retry 5 --retry-delay 5 -o "${out}.part" "$url"
  mv "${out}.part" "$out"
}

declare -A PATHS=(
  [HG001]="NA12878_HG001/NISTv4.2.1/GRCh38"
  [HG002]="AshkenazimTrio/HG002_NA24385_son/NISTv4.2.1/GRCh38"
  [HG005]="ChineseTrio/HG005_NA24631_son/NISTv4.2.1/GRCh38"
)

for sample in "${!PATHS[@]}"; do
  path="${PATHS[$sample]}"
  echo "==> ${sample}"
  fetch "${OUTDIR}/${sample}_GRCh38_1_22_v4.2.1_benchmark.vcf.gz" \
    "${NIST}/${path}/${sample}_GRCh38_1_22_v4.2.1_benchmark.vcf.gz"
  fetch "${OUTDIR}/${sample}_GRCh38_1_22_v4.2.1_benchmark.vcf.gz.tbi" \
    "${NIST}/${path}/${sample}_GRCh38_1_22_v4.2.1_benchmark.vcf.gz.tbi"
  fetch "${OUTDIR}/${sample}_GRCh38_1_22_v4.2.1_benchmark_noinconsistent.bed" \
    "${NIST}/${path}/${sample}_GRCh38_1_22_v4.2.1_benchmark_noinconsistent.bed"
done

echo "==> Stratification BEDs (low-complexity, segmental duplications)"
STRAT="${NIST}/genome-stratifications/v3.1"
fetch "${OUTDIR}/stratification/LowComplexity.bed.gz" \
  "${STRAT}/GRCh38/LowComplexity/GRCh38_AllTandemRepeatsandHomopolymers_slop5.bed.gz"
fetch "${OUTDIR}/stratification/SegmentalDuplications.bed.gz" \
  "${STRAT}/GRCh38/SegmentalDuplications/GRCh38_segdups.bed.gz"

# hap.py's --stratification option takes one TSV file (name, then BED file,
# separated by a tab). It cannot take a comma-separated list of BED files.
printf 'LowComplexity\tLowComplexity.bed.gz\nSegmentalDuplications\tSegmentalDuplications.bed.gz\n' \
  > "${OUTDIR}/stratification/strat.tsv"

echo "==> Done"
ls -lh "$OUTDIR"
echo "GIAB has no African or South Asian sample, so there is nothing to download for those."
echo "If a download gives a 404, NIST has moved the file: https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/"
