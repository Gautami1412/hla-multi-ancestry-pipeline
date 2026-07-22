# Single reproducible image containing every tool the pipeline needs:
# Snakemake itself + all bioinformatics tools + AWS CLI. Used for:
#   1. Local `docker run` execution (no conda install needed on your laptop)
#   2. Pushed to ECR and used as the AWS Batch job container
#
# Build:   docker build -t hla-pipeline:latest -f docker/Dockerfile .
# Run:     docker run --rm -v $(pwd):/work -w /work hla-pipeline:latest \
#              snakemake --cores 4 --use-conda -n

FROM mambaorg/micromamba:1.5.8

USER root
WORKDIR /work

# System deps: AWS CLI needs curl/unzip; bedtools/gatk need a JRE.
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl unzip default-jre-headless procps \
    && rm -rf /var/lib/apt/lists/*

# AWS CLI v2
RUN curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip -q awscliv2.zip && ./aws/install && rm -rf awscliv2.zip aws

# Bioinformatics + workflow tools, pinned, from bioconda/conda-forge.
COPY docker/environment.yml /tmp/environment.yml
RUN micromamba install -y -n base -f /tmp/environment.yml \
    && micromamba clean --all --yes

ENV PATH=/opt/conda/bin:$PATH
SHELL ["/bin/bash", "-c"]

ENTRYPOINT ["/usr/local/bin/_entrypoint.sh"]
CMD ["snakemake", "--help"]
