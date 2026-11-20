#!/usr/bin/env bash
# Downloads the shared reference files: Broad's hg38 FASTA, dbSNP build 138
# and the Mills/1000G gold-standard indels. Run once, then keep the files in S3.
#
# The FASTA still contains the *_alt contigs. Run
# scripts/make_no_alt_reference.sh afterwards to remove them.
#
# Needs bgzip and tabix (both come with the samtools conda environment).
set -euo pipefail

OUTDIR="resources/reference"
mkdir -p "$OUTDIR"

BASE="https://storage.googleapis.com/gcp-public-data--broad-references/hg38/v0"

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

echo "==> Reference FASTA"
fetch "${OUTDIR}/Homo_sapiens_assembly38.fasta" "${BASE}/Homo_sapiens_assembly38.fasta"

echo "==> dbSNP build 138"
if [[ ! -s "${OUTDIR}/dbsnp_138.hg38.vcf.gz.tbi" ]]; then
  fetch "${OUTDIR}/dbsnp_138.hg38.vcf" "${BASE}/Homo_sapiens_assembly38.dbsnp138.vcf"
  # GATK needs bgzip, not plain gzip, so it can jump around inside the file.
  bgzip -f "${OUTDIR}/dbsnp_138.hg38.vcf"
  tabix -f -p vcf "${OUTDIR}/dbsnp_138.hg38.vcf.gz"
fi

echo "==> Mills/1000G gold-standard indels"
fetch "${OUTDIR}/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz" \
  "${BASE}/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz"
fetch "${OUTDIR}/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz.tbi" \
  "${BASE}/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz.tbi"

echo "==> Done"
ls -lh "$OUTDIR"
echo "If a download gives a 404, Broad has moved the file. The current paths are listed at"
echo "https://gatk.broadinstitute.org/hc/en-us/articles/360035890811"
