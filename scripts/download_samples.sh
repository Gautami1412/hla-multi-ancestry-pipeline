#!/usr/bin/env bash
# Downloads only the HLA-region slice of each sample's CRAM. samtools reads
# the remote CRAM over HTTPS and fetches just the region, so the full
# multi-GB file is never downloaded. It does this for every sample in
# samples.tsv and giab_samples.tsv.
#
# Needs samtools 1.10 or newer with libcurl support (the conda environment in
# envs/align.yaml has it) and the original Broad FASTA from
# scripts/download_reference.sh, because decoding a CRAM needs the same
# reference it was made with.
set -euo pipefail

mkdir -p resources/cram
REF="resources/reference/Homo_sapiens_assembly38.fasta"
BED="resources/regions/hla_extended.bed"
REGION=$(awk '{print $1":"$2"-"$3}' "$BED")

# Some source servers (NCBI's older ftp-trace one in particular) accept the
# connection and then stall with no data, and samtools has no read timeout of
# its own, so it would hang forever. timeout gives each sample a time limit
# so a stall shows up as a failure.
DOWNLOAD_TIMEOUT_SECS="${DOWNLOAD_TIMEOUT_SECS:-2700}"

download_one() {
  local sample="$1" url="$2"
  local out="resources/cram/${sample}.full.cram"
  if [[ -s "$out" && -s "${out}.crai" ]]; then
    echo "==> ${sample}: already downloaded, skipping"
    return 0
  fi
  echo "==> ${sample}: slicing ${REGION} from ${url}"
  # The output is the sliced "full.cram" that rules/01_extract_region.smk expects.
  if ! timeout -k 30 "$DOWNLOAD_TIMEOUT_SECS" samtools view -C -T "$REF" -o "$out" "$url" "$REGION"; then
    echo "==> ${sample}: FAILED (timed out after ${DOWNLOAD_TIMEOUT_SECS}s or errored, possibly a stalled connection)" >&2
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

echo "==> Done. If any sample failed, run scripts/verify_urls.sh to check its URL."
