"""
Stage 2 — Read QC and trimming.
FastQC on raw reads, fastp for adapter/quality trimming, MultiQC to
aggregate everything (raw + trimmed reports) into one summary.
"""

rule fastqc_raw:
    input:
        r1 = f"{RESULTS}/fastq_raw/{{sample}}_R1.fastq.gz",
        r2 = f"{RESULTS}/fastq_raw/{{sample}}_R2.fastq.gz",
    output:
        html1 = f"{RESULTS}/qc/fastqc_raw/{{sample}}_R1_fastqc.html",
        html2 = f"{RESULTS}/qc/fastqc_raw/{{sample}}_R2_fastqc.html",
    params:
        outdir = f"{RESULTS}/qc/fastqc_raw"
    conda:
        "../envs/qc.yaml"
    log:
        f"{LOGS}/fastqc/{{sample}}.log"
    shell:
        "fastqc -o {params.outdir} {input.r1} {input.r2} > {log} 2>&1"


rule fastp_trim:
    input:
        r1 = f"{RESULTS}/fastq_raw/{{sample}}_R1.fastq.gz",
        r2 = f"{RESULTS}/fastq_raw/{{sample}}_R2.fastq.gz",
    output:
        r1 = f"{RESULTS}/fastq_trimmed/{{sample}}_R1.trim.fastq.gz",
        r2 = f"{RESULTS}/fastq_trimmed/{{sample}}_R2.trim.fastq.gz",
        html = f"{RESULTS}/qc/fastp/{{sample}}.fastp.html",
        json = f"{RESULTS}/qc/fastp/{{sample}}.fastp.json",
    params:
        extra = config["fastp"]["extra"]
    conda:
        "../envs/qc.yaml"
    threads: 2
    log:
        f"{LOGS}/fastp/{{sample}}.log"
    shell:
        """
        fastp -i {input.r1} -I {input.r2} \
            -o {output.r1} -O {output.r2} \
            -h {output.html} -j {output.json} \
            --thread {threads} {params.extra} > {log} 2>&1
        """


rule multiqc:
    input:
        expand(f"{RESULTS}/qc/fastqc_raw/{{sample}}_R1_fastqc.html", sample=SAMPLES),
        expand(f"{RESULTS}/qc/fastp/{{sample}}.fastp.json", sample=SAMPLES),
    output:
        f"{RESULTS}/qc/multiqc_report.html"
    params:
        indir = f"{RESULTS}/qc",
        outdir = f"{RESULTS}/qc"
    conda:
        "../envs/qc.yaml"
    log:
        f"{LOGS}/multiqc.log"
    shell:
        "multiqc {params.indir} -o {params.outdir} -n multiqc_report.html > {log} 2>&1"
