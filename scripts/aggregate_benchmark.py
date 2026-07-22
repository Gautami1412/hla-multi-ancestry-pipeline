"""
Called via Snakemake's `script:` directive from rules/08_benchmark.smk.
Combines each GIAB sample's hap.py summary.csv into one ancestry-labeled
report, and explicitly lists cohort samples that have NO truth set at all
(AFR, SAS) so that absence shows up in the deliverable, not just the README.

Available injected objects: snakemake.input, snakemake.output, snakemake.params
"""
import pandas as pd

rows = []
# hap.py summary.csv has columns: Type, Filter, TRUTH.TOTAL, TRUTH.TP, TRUTH.FN,
# QUERY.TOTAL, QUERY.FP, ..., METRIC.Recall, METRIC.Precision, METRIC.F1_Score
for csv_path in snakemake.input.summaries:
    sample = [s for s in snakemake.params.ancestry_map if s in csv_path][0]
    df = pd.read_csv(csv_path)
    df = df[df["Filter"] == "PASS"]
    df["sample"] = sample
    df["ancestry"] = snakemake.params.ancestry_map.get(sample, "unknown")
    df["has_truth_set"] = True
    rows.append(df[["sample", "ancestry", "Type", "has_truth_set",
                     "METRIC.Recall", "METRIC.Precision", "METRIC.F1_Score"]])

report = pd.concat(rows, ignore_index=True) if rows else pd.DataFrame(
    columns=["sample", "ancestry", "Type", "has_truth_set",
             "METRIC.Recall", "METRIC.Precision", "METRIC.F1_Score"]
)

# Explicitly record cohort samples with NO GIAB truth set — this row set is
# the reference-bias headline: whole ancestry groups can't even be scored.
benchmarked_samples = set(report["sample"])
no_truth_rows = []
for sample in snakemake.params.all_cohort_samples:
    if sample not in benchmarked_samples:
        no_truth_rows.append({
            "sample": sample,
            "ancestry": snakemake.params.ancestry_map.get(sample, "unknown"),
            "Type": "N/A",
            "has_truth_set": False,
            "METRIC.Recall": None,
            "METRIC.Precision": None,
            "METRIC.F1_Score": None,
        })
report = pd.concat([report, pd.DataFrame(no_truth_rows)], ignore_index=True)

report = report.sort_values(["ancestry", "sample", "Type"])
report.to_csv(snakemake.output[0], sep="\t", index=False)

# Quick group-level summary printed to the Snakemake log for a fast read.
summarizable = report[report["has_truth_set"] == True]
if not summarizable.empty:
    group_summary = summarizable.groupby(["ancestry", "Type"])[
        ["METRIC.Recall", "METRIC.Precision", "METRIC.F1_Score"]
    ].mean()
    print("\n=== Ancestry-stratified accuracy (mean over benchmarked samples) ===")
    print(group_summary)
print("\n=== Cohort samples with NO GIAB truth set (unscorable) ===")
print(report[report["has_truth_set"] == False][["sample", "ancestry"]])
