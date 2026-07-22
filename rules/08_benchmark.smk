"""
Stage 8 — Ancestry-stratified benchmarking (the actual point of the project).
For each GIAB sample: pull its genotype column out of the jointly-called,
filtered cohort VCF, then run hap.py against the matched NIST truth VCF,
restricted to (GIAB confident regions) AND (our HLA interval), optionally
further stratified by GIAB's low-complexity / segdup BED files.

AFR and SAS cohort samples are NOT benchmarked here because no GIAB truth
set exists for them — see README for why that gap is itself the finding.
"""

rule extract_sample_vcf:
    input:
        vcf = f"{RESULTS}/filtered/cohort.filtered.vcf.gz",
        ref = config["reference"]["fasta"],
        fai = REF_FAI,
        seqdict = REF_DICT,
    output:
        f"{RESULTS}/filtered/per_sample/{{sample}}.filtered.vcf.gz"
    conda:
        "../envs/align.yaml"
    shell:
        """
        gatk SelectVariants -R {input.ref} -V {input.vcf} \
            -sn {wildcards.sample} --exclude-non-variants --remove-unused-alternates \
            -O {output}
        """


rule intersect_confident_region:
    """Confident-call region for this GIAB sample, intersected with our
    HLA interval, so hap.py only scores the region we actually called."""
    input:
        giab_bed = lambda wc: config["giab"][wc.sample]["confident_bed"],
        hla_bed = config["region"]["bed"],
    output:
        f"{RESULTS}/benchmark/{{sample}}/{{sample}}.eval_regions.bed"
    conda:
        "../envs/happy.yaml"
    shell:
        "bedtools intersect -a {input.giab_bed} -b {input.hla_bed} > {output}"


rule run_happy:
    input:
        query = f"{RESULTS}/filtered/per_sample/{{sample}}.filtered.vcf.gz",
        truth = lambda wc: config["giab"][wc.sample]["truth_vcf"],
        regions = f"{RESULTS}/benchmark/{{sample}}/{{sample}}.eval_regions.bed",
        ref = config["reference"]["fasta"],
        fai = REF_FAI,
    output:
        summary = f"{RESULTS}/benchmark/{{sample}}/{{sample}}.summary.csv"
    params:
        prefix = f"{RESULTS}/benchmark/{{sample}}/{{sample}}",
        strat_beds = ",".join(config["happy"]["stratification_beds"]),
    conda:
        "../envs/happy.yaml"
    log:
        f"{LOGS}/happy/{{sample}}.log"
    shell:
        """
        hap.py {input.truth} {input.query} \
            -f {input.regions} \
            -r {input.ref} \
            --stratification {params.strat_beds} \
            -o {params.prefix} > {log} 2>&1
        """


rule aggregate_ancestry_report:
    input:
        summaries = expand(f"{RESULTS}/benchmark/{{sample}}/{{sample}}.summary.csv", sample=GIAB_SAMPLES)
    output:
        f"{RESULTS}/benchmark/ancestry_stratified_report.tsv"
    params:
        ancestry_map = ANCESTRY_OF,
        all_cohort_samples = COHORT_SAMPLES,
        ancestry_groups = ANCESTRY_GROUPS,
    script:
        "../scripts/aggregate_benchmark.py"
