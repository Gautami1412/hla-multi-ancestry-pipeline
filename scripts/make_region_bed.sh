#!/usr/bin/env bash
# Writes the extended HLA region BED file used by every -L flag in the
# pipeline. Values come from config/config.yaml (region.contig/start/end).
set -euo pipefail

# Match on "<key>:" so substring collisions don't fire — e.g. a bare
# `grep end` also matches `name: "HLA_extended"` (…ext-END-ed), corrupting
# the BED. Anchoring to the key prevents that.
CONTIG=$(grep -A4 "^region:" config/config.yaml | grep 'contig:' | awk '{print $2}' | tr -d '"')
START=$(grep -A4 "^region:" config/config.yaml | grep 'start:' | awk '{print $2}' | tr -d '"')
END=$(grep -A4 "^region:" config/config.yaml | grep 'end:' | awk '{print $2}' | tr -d '"')
OUT="resources/regions/hla_extended.bed"

mkdir -p "$(dirname "$OUT")"
printf "%s\t%s\t%s\tHLA_extended\n" "$CONTIG" "$START" "$END" > "$OUT"
echo "Wrote $OUT:"
cat "$OUT"
