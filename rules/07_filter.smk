"""
Stage 7 — Variant filtering.
GATK documented hard-filter defaults (config['hard_filters']), applied
separately to SNPs and indels then merged back together. VQSR needs a
much larger cohort than this demo has — noted in README as the
production-scale alternative.
"""

rule select_snps:
    input:
        vcf = f"{RESULTS}/joint/cohort.raw.vcf.gz",
        ref = config["reference"]["fasta"],
        fai = REF_FAI,
        seqdict = REF_DICT,
    output:
        f"{RESULTS}/filtered/cohort.snps.vcf.gz"
    conda:
        "../envs/align.yaml"
    shell:
        "gatk SelectVariants -R {input.ref} -V {input.vcf} --select-type-to-include SNP -O {output}"


rule select_indels:
    input:
        vcf = f"{RESULTS}/joint/cohort.raw.vcf.gz",
        ref = config["reference"]["fasta"],
        fai = REF_FAI,
        seqdict = REF_DICT,
    output:
        f"{RESULTS}/filtered/cohort.indels.vcf.gz"
    conda:
        "../envs/align.yaml"
    shell:
        "gatk SelectVariants -R {input.ref} -V {input.vcf} --select-type-to-include INDEL -O {output}"


def snp_filter_expr():
    f = config["hard_filters"]["snp"]
    return " ".join(f'--filter-name "{name}" --filter-expression "{expr}"' for name, expr in f.items())


def indel_filter_expr():
    f = config["hard_filters"]["indel"]
    return " ".join(f'--filter-name "{name}" --filter-expression "{expr}"' for name, expr in f.items())


rule hard_filter_snps:
    input:
        vcf = f"{RESULTS}/filtered/cohort.snps.vcf.gz",
        ref = config["reference"]["fasta"],
        fai = REF_FAI,
        seqdict = REF_DICT,
    output:
        f"{RESULTS}/filtered/cohort.snps.filtered.vcf.gz"
    params:
        filters = snp_filter_expr()
    conda:
        "../envs/align.yaml"
    shell:
        "gatk VariantFiltration -R {input.ref} -V {input.vcf} {params.filters} -O {output}"


rule hard_filter_indels:
    input:
        vcf = f"{RESULTS}/filtered/cohort.indels.vcf.gz",
        ref = config["reference"]["fasta"],
        fai = REF_FAI,
        seqdict = REF_DICT,
    output:
        f"{RESULTS}/filtered/cohort.indels.filtered.vcf.gz"
    params:
        filters = indel_filter_expr()
    conda:
        "../envs/align.yaml"
    shell:
        "gatk VariantFiltration -R {input.ref} -V {input.vcf} {params.filters} -O {output}"


rule merge_filtered:
    input:
        snps = f"{RESULTS}/filtered/cohort.snps.filtered.vcf.gz",
        indels = f"{RESULTS}/filtered/cohort.indels.filtered.vcf.gz",
    output:
        f"{RESULTS}/filtered/cohort.filtered.vcf.gz"
    conda:
        "../envs/align.yaml"
    shell:
        """
        gatk MergeVcfs -I {input.snps} -I {input.indels} -O {output}
        """
