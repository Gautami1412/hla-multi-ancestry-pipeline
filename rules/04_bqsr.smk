"""
Stage 4 — Base Quality Score Recalibration (BQSR).
The step most copy-pasted tutorials skip. Corrects systematic sequencer
error patterns using dbSNP + Mills/1000G gold-standard indels as known
sites, restricted to the HLA region interval for speed.
"""

rule base_recalibrator:
    input:
        bam = f"{RESULTS}/dedup/{{sample}}.dedup.bam",
        bai = f"{RESULTS}/dedup/{{sample}}.dedup.bam.bai",
        ref = config["reference"]["fasta"],
        fai = REF_FAI,
        seqdict = REF_DICT,
        dbsnp = config["reference"]["dbsnp"],
        mills = config["reference"]["mills_indels"],
        intervals = config["region"]["bed"],
    output:
        table = f"{RESULTS}/bqsr/{{sample}}.recal_data.table"
    params:
        java_opts = config["gatk"]["java_opts"],
    conda:
        "../envs/align.yaml"
    log:
        f"{LOGS}/bqsr/{{sample}}.recal.log"
    shell:
        """
        gatk --java-options "{params.java_opts}" BaseRecalibrator \
            -I {input.bam} -R {input.ref} \
            --known-sites {input.dbsnp} --known-sites {input.mills} \
            -L {input.intervals} \
            -O {output.table} > {log} 2>&1
        """


rule apply_bqsr:
    input:
        bam = f"{RESULTS}/dedup/{{sample}}.dedup.bam",
        ref = config["reference"]["fasta"],
        fai = REF_FAI,
        seqdict = REF_DICT,
        table = f"{RESULTS}/bqsr/{{sample}}.recal_data.table",
    output:
        bam = f"{RESULTS}/bqsr/{{sample}}.recal.bam"
    params:
        java_opts = config["gatk"]["java_opts"],
    conda:
        "../envs/align.yaml"
    log:
        f"{LOGS}/bqsr/{{sample}}.apply.log"
    shell:
        """
        gatk --java-options "{params.java_opts}" ApplyBQSR \
            -I {input.bam} -R {input.ref} \
            --bqsr-recal-file {input.table} \
            -O {output.bam} > {log} 2>&1
        """


rule index_recal_bam:
    input:
        f"{RESULTS}/bqsr/{{sample}}.recal.bam"
    output:
        f"{RESULTS}/bqsr/{{sample}}.recal.bam.bai"
    conda:
        "../envs/align.yaml"
    shell:
        "samtools index {input}"
