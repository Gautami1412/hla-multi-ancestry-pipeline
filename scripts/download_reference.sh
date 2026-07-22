#!/usr/bin/env bash
# Downloads the GRCh38 reference FASTA, dbSNP, and Mills/1000G gold-standard
# indels — the shared, one-time resources needed by BQSR and variant calling.
# These are standard GATK resource bundle files hosted publicly by the
# Broad Institute. ~3-4 GB total; run once, then reuse (or push to S3).
set -euo pipefail

OUTDIR="resources/reference"
mkdir -p "$OUTDIR"

BASE="https://storage.googleapis.com/genomics-public-data/resources/broad/hg38/v0"

echo "==> Reference FASTA (+ index + dict)"
curl -L -o "${OUTDIR}/GRCh38_full_analysis_set_plus_decoy_hla.fa" \
  "${BASE}/Homo_sapiens_assembly38.fasta"
curl -L -o "${OUTDIR}/GRCh38_full_analysis_set_plus_decoy_hla.fa.fai" \
  "${BASE}/Homo_sapiens_assembly38.fasta.fai"
curl -L -o "${OUTDIR}/GRCh38_full_analysis_set_plus_decoy_hla.dict" \
  "${BASE}/Homo_sapiens_assembly38.dict"

echo "==> dbSNP"
curl -L -o "${OUTDIR}/dbsnp_146.hg38.vcf.gz" "${BASE}/Homo_sapiens_assembly38.dbsnp138.vcf"
gzip -f "${OUTDIR}/dbsnp_146.hg38.vcf.gz" 2>/dev/null || true
curl -L -o "${OUTDIR}/dbsnp_146.hg38.vcf.gz.tbi" "${BASE}/Homo_sapiens_assembly38.dbsnp138.vcf.idx" || true

echo "==> Mills/1000G gold-standard indels"
curl -L -o "${OUTDIR}/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz" \
  "${BASE}/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz"
curl -L -o "${OUTDIR}/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz.tbi" \
  "${BASE}/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz.tbi"

echo "==> Done. Verify checksums / file sizes look sane before proceeding:"
ls -lh "$OUTDIR"

echo ""
echo "NOTE: Broad occasionally reorganizes this bucket's layout. If any curl"
echo "above 404s, get the current path from:"
echo "https://console.cloud.google.com/storage/browser/genomics-public-data/resources/broad/hg38/v0"
echo "or the GATK resource bundle docs: https://gatk.broadinstitute.org/hc/en-us/articles/360035890811"
