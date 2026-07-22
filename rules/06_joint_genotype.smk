"""
Stage 6 — Joint genotyping across the cohort.
CombineGVCFs (fine for a cohort this small — GenomicsDBImport is the
scale-up alternative, noted in README) followed by GenotypeGVCFs to call
variants across all samples simultaneously. This is the standard GATK
cohort approach and improves accuracy vs. per-sample calling.
"""

rule combine_gvcfs:
    input:
        gvcfs = expand(f"{RESULTS}/gvcf/{{sample}}.g.vcf.gz", sample=SAMPLES),
        ref = config["reference"]["fasta"],
        fai = REF_FAI,
        seqdict = REF_DICT,
    output:
        f"{RESULTS}/joint/cohort.combined.g.vcf.gz"
    params:
        variant_args = lambda wc, input: " ".join(f"-V {g}" for g in input.gvcfs),
        java_opts = config["gatk"]["java_opts"],
    conda:
        "../envs/align.yaml"
    log:
        f"{LOGS}/joint/combine_gvcfs.log"
    shell:
        """
        gatk --java-options "{params.java_opts}" CombineGVCFs \
            -R {input.ref} {params.variant_args} \
            -O {output} > {log} 2>&1
        """


rule genotype_gvcfs:
    input:
        combined = f"{RESULTS}/joint/cohort.combined.g.vcf.gz",
        ref = config["reference"]["fasta"],
        fai = REF_FAI,
        seqdict = REF_DICT,
    output:
        f"{RESULTS}/joint/cohort.raw.vcf.gz"
    params:
        java_opts = config["gatk"]["java_opts"],
    conda:
        "../envs/align.yaml"
    log:
        f"{LOGS}/joint/genotype_gvcfs.log"
    shell:
        """
        gatk --java-options "{params.java_opts}" GenotypeGVCFs \
            -R {input.ref} -V {input.combined} \
            -O {output} > {log} 2>&1
        """
