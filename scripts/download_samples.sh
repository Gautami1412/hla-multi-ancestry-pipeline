#!/usr/bin/env bash
# Downloads only the HLA-region slice of each sample's CRAM using an
# HTTP range-capable tool (samtools can stream-slice a remote CRAM
# directly without pulling the whole multi-GB file), for every sample in
# samples.tsv AND giab_samples.tsv.
#
# Requires: samtools >= 1.10 built with libcurl support (the conda env in
# envs/align.yaml has this). Needs the reference FASTA already present
# (resources/reference/...) because CRAM decoding needs it.
set -euo pipefail

mkdir -p resources/cram
REF="resources/reference/GRCh38_full_analysis_set_plus_decoy_hla.fa"
BED="resources/regions/hla_extended.bed"
REGION=$(awk '{print $1":"$2"-"$3}' "$BED")

download_one() {
  local sample="$1" url="$2"
  echo "==> ${sample}: slicing ${REGION} from ${url}"
  # samtools view can read directly over HTTPS; -T supplies the reference
  # for CRAM decoding. Output is already the sliced "full.cram" the
  # Snakemake rule 01_extract_region.smk expects.
  samtools view -C -T "$REF" -o "resources/cram/${sample}.full.cram" "$url" "$REGION"
  samtools index "resources/cram/${sample}.full.cram"
}

echo "==> Cohort samples"
tail -n +2 samples.tsv | while IFS=$'\t' read -r sample ancestry population sex url; do
  download_one "$sample" "$url"
done

echo "==> GIAB reference samples"
grep -v '^#' giab_samples.tsv | tail -n +2 | while IFS=$'\t' read -r sample ancestry url; do
  download_one "$sample" "$url"
done

echo "==> Done. Run scripts/verify_urls.sh beforehand next time if any of these failed."
