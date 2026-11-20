#!/usr/bin/env bash
# Makes the reference the pipeline actually uses: Broad's hg38 FASTA with the
# 261 *_alt contigs removed (3366 contigs before, 3105 after).
#
# Why: with the alt contigs in the reference, BWA-MEM finds reads from the HLA
# region matching both the main chr6 sequence and an alt copy equally well, so
# it gives them mapping quality 0. GATK ignores those reads, and almost no
# variants were called there. Removing the alt contigs fixes that. The main
# chromosomes, the decoy contigs and the HLA allele contigs are kept.
#
# The BWA index, .fai and .dict files are built from this FASTA by the rules in
# rules/00_reference.smk, or on AWS with aws/build_reference_index.sh.
set -euo pipefail

IN="resources/reference/Homo_sapiens_assembly38.fasta"
OUT="resources/reference/GRCh38_no_alt_plus_decoy_hla.fa"

if [[ ! -s "$IN" ]]; then
  echo "Missing $IN. Run scripts/download_reference.sh first." >&2
  exit 1
fi

# Keep a record unless its name (the first word of the header) ends in _alt.
awk '/^>/ {keep = ($1 !~ /_alt$/)} keep' "$IN" > "$OUT"

echo "contigs before: $(grep -c '^>' "$IN")"
echo "contigs after:  $(grep -c '^>' "$OUT")"
echo "alt contigs left (should be 0): $(grep '^>' "$OUT" | awk '{print $1}' | grep -c '_alt$' || true)"
