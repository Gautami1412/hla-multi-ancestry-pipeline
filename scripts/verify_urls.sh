#!/usr/bin/env bash
# Sanity-checks that every CRAM URL in samples.tsv and giab_samples.tsv
# actually resolves before you start a long download. The exact ENA/1000G
# run accessions and GIAB FTP paths in this repo are illustrative — 1000
# Genomes and GIAB both reorganize directory layouts over time, so ALWAYS
# run this first and fix any broken rows before scripts/download_samples.sh.
set -euo pipefail

check() {
  local sample="$1" url="$2"
  # A couple of these FTP hosts (esp. NCBI's) intermittently flake on the
  # TLS handshake under a fresh connection; retry before declaring FAIL so
  # a good URL doesn't get "fixed" into a worse one.
  if curl -sI --max-time 15 --retry 3 --retry-delay 3 --retry-all-errors "$url" | head -1 | grep -qE "200|206"; then
    echo "OK    ${sample}"
  else
    echo "FAIL  ${sample}  ${url}"
  fi
}

echo "==> Checking samples.tsv"
tail -n +2 samples.tsv | while IFS=$'\t' read -r sample ancestry population sex url; do
  check "$sample" "$url"
done

echo "==> Checking giab_samples.tsv"
grep -v '^#' giab_samples.tsv | tail -n +2 | while IFS=$'\t' read -r sample ancestry url; do
  check "$sample" "$url"
done

echo ""
echo "If anything FAILed: browse the current index and fix the URL in the"
echo "relevant .tsv row before downloading."
echo "  1000 Genomes high-coverage index:"
echo "  http://ftp.1000genomes.ebi.ac.uk/vol1/ftp/data_collections/1000G_2504_high_coverage/data/"
echo "  GIAB release index:"
echo "  https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/"
