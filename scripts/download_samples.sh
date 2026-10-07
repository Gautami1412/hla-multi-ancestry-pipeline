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

# Some source hosts (esp. NCBI's legacy ftp-trace server) have been seen to
# accept the connection and then stall indefinitely with zero throughput —
# htslib's libcurl backend has no read-timeout of its own, so a stalled
# transfer hangs forever instead of failing. `timeout` bounds each sample to
# a fixed wall-clock budget so a stall surfaces as a clear failure.
DOWNLOAD_TIMEOUT_SECS="${DOWNLOAD_TIMEOUT_SECS:-2700}"

download_one() {
  local sample="$1" url="$2"
  local out="resources/cram/${sample}.full.cram"
  if [[ -s "$out" && -s "${out}.crai" ]]; then
    echo "==> ${sample}: already downloaded, skipping"
    return 0
  fi
  echo "==> ${sample}: slicing ${REGION} from ${url}"
  # samtools view can read directly over HTTPS; -T supplies the reference
  # for CRAM decoding. Output is already the sliced "full.cram" the
  # Snakemake rule 01_extract_region.smk expects.
  if ! timeout -k 30 "$DOWNLOAD_TIMEOUT_SECS" samtools view -C -T "$REF" -o "$out" "$url" "$REGION"; then
    echo "==> ${sample}: FAILED (timed out after ${DOWNLOAD_TIMEOUT_SECS}s or errored — possible stalled connection)" >&2
    rm -f "$out"
    return 1
  fi
  samtools index "$out"
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
