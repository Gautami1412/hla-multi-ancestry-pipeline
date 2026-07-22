"""
Stage 1 (compute-feasibility step, not in the original 8-step list but
required to make it runnable on a laptop) — pull only HLA-region reads
out of each sample's public 1000 Genomes high-coverage CRAM, then convert
back to FASTQ so the rest of the pipeline (QC -> trim -> align -> ...)
runs exactly as it would on a full WGS sample, just on ~1/500th the data.

This is standard practice for regional re-analysis. It is called out
explicitly in the README as a deviation from "align whole-genome FASTQ"
so it doesn't get mistaken for the full GATK Best Practices WGS pipeline.
"""

rule slice_region_cram:
    # Expects resources/cram/{sample}.full.cram to already exist locally —
    # fetched by scripts/download_samples.sh (streams only, doesn't keep
    # the full CRAM around any longer than needed for the slice below).
    input:
        cram = "resources/cram/{sample}.full.cram",
        bed = config["region"]["bed"],
        ref = config["reference"]["fasta"],
        fai = REF_FAI,
    output:
        bam = temp(f"{RESULTS}/sliced/{{sample}}.hla.bam")
    conda:
        "../envs/align.yaml"
    log:
        f"{LOGS}/slice/{{sample}}.log"
    shell:
        """
        samtools view -b -T {input.ref} -L {input.bed} {input.cram} > {output.bam} 2> {log}
        """

rule sort_by_name_for_fastq:
    input:
        f"{RESULTS}/sliced/{{sample}}.hla.bam"
    output:
        temp(f"{RESULTS}/sliced/{{sample}}.hla.qsort.bam")
    conda:
        "../envs/align.yaml"
    threads: 2
    shell:
        "samtools sort -n -@ {threads} -o {output} {input}"

rule bam_to_fastq:
    input:
        f"{RESULTS}/sliced/{{sample}}.hla.qsort.bam"
    output:
        r1 = f"{RESULTS}/fastq_raw/{{sample}}_R1.fastq.gz",
        r2 = f"{RESULTS}/fastq_raw/{{sample}}_R2.fastq.gz",
    conda:
        "../envs/align.yaml"
    log:
        f"{LOGS}/bam2fastq/{{sample}}.log"
    shell:
        """
        samtools fastq -1 {output.r1} -2 {output.r2} \
            -0 /dev/null -s /dev/null -n {input} > {log} 2>&1
        """
