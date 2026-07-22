"""
Stage 5 — Per-sample variant calling (HaplotypeCaller, GVCF mode).
One GVCF per sample. Genotypes are NOT called here — that happens jointly
in stage 6. This is required for proper cohort joint genotyping.
"""

rule haplotypecaller_gvcf:
    input:
        bam = f"{RESULTS}/bqsr/{{sample}}.recal.bam",
        bai = f"{RESULTS}/bqsr/{{sample}}.recal.bam.bai",
        ref = config["reference"]["fasta"],
        fai = REF_FAI,
        seqdict = REF_DICT,
        intervals = config["region"]["bed"],
    output:
        gvcf = f"{RESULTS}/gvcf/{{sample}}.g.vcf.gz"
    params:
        extra = config["gatk"]["haplotypecaller_extra"],
        java_opts = config["gatk"]["java_opts"],
    conda:
        "../envs/align.yaml"
    threads: 2
    log:
        f"{LOGS}/haplotypecaller/{{sample}}.log"
    shell:
        """
        gatk --java-options "{params.java_opts}" HaplotypeCaller \
            -I {input.bam} -R {input.ref} \
            -L {input.intervals} \
            {params.extra} \
            -O {output.gvcf} > {log} 2>&1
        """
