"""
Stage 3 — Alignment & BAM preprocessing.
BWA-MEM -> sort -> MarkDuplicates. BQSR is its own stage (04) since it
needs the known-sites resources and is the step most tutorials skip.
"""

rule bwa_mem_align:
    input:
        r1 = f"{RESULTS}/fastq_trimmed/{{sample}}_R1.trim.fastq.gz",
        r2 = f"{RESULTS}/fastq_trimmed/{{sample}}_R2.trim.fastq.gz",
        ref = config["reference"]["fasta"],
        idx = multiext(config["reference"]["fasta"], ".amb", ".ann", ".bwt", ".pac", ".sa"),
    output:
        bam = temp(f"{RESULTS}/aligned/{{sample}}.sorted.bam")
    params:
        rg = lambda wc: f"@RG\\tID:{wc.sample}\\tSM:{wc.sample}\\tPL:ILLUMINA\\tLB:{wc.sample}",
        threads = config["bwa"]["threads"],
    conda:
        "../envs/align.yaml"
    threads: config["bwa"]["threads"]
    log:
        f"{LOGS}/align/{{sample}}.log"
    shell:
        """
        bwa mem -t {threads} -R '{params.rg}' {input.ref} {input.r1} {input.r2} 2> {log} \
            | samtools sort -@ {threads} -o {output.bam} - 2>> {log}
        """


rule mark_duplicates:
    input:
        f"{RESULTS}/aligned/{{sample}}.sorted.bam"
    output:
        bam = f"{RESULTS}/dedup/{{sample}}.dedup.bam",
        metrics = f"{RESULTS}/dedup/{{sample}}.dup_metrics.txt",
    conda:
        "../envs/align.yaml"
    log:
        f"{LOGS}/markdup/{{sample}}.log"
    shell:
        """
        gatk MarkDuplicates -I {input} -O {output.bam} -M {output.metrics} > {log} 2>&1
        """


rule index_dedup_bam:
    input:
        f"{RESULTS}/dedup/{{sample}}.dedup.bam"
    output:
        f"{RESULTS}/dedup/{{sample}}.dedup.bam.bai"
    conda:
        "../envs/align.yaml"
    shell:
        "samtools index {input}"
