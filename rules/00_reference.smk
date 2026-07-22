"""
Stage 0 — Reference & known-sites resources.
These files are downloaded once via scripts/download_reference.sh and
scripts/download_giab.sh (not by Snakemake itself, since they're large,
one-time, shared downloads better run explicitly — see README).
This rule file only builds the BWA/GATK indexes on top of them.
"""

rule bwa_index:
    input:
        config["reference"]["fasta"]
    output:
        multiext(config["reference"]["fasta"], ".amb", ".ann", ".bwt", ".pac", ".sa")
    conda:
        "../envs/align.yaml"
    log:
        f"{LOGS}/reference/bwa_index.log"
    shell:
        "bwa index {input} > {log} 2>&1"


rule fasta_dict:
    input:
        config["reference"]["fasta"]
    output:
        config["reference"]["fasta"].replace(".fa", ".dict")
    conda:
        "../envs/align.yaml"
    log:
        f"{LOGS}/reference/fasta_dict.log"
    shell:
        "gatk CreateSequenceDictionary -R {input} -O {output} > {log} 2>&1"


rule fasta_faidx:
    input:
        config["reference"]["fasta"]
    output:
        config["reference"]["fasta"] + ".fai"
    conda:
        "../envs/align.yaml"
    log:
        f"{LOGS}/reference/faidx.log"
    shell:
        "samtools faidx {input} > {log} 2>&1"
