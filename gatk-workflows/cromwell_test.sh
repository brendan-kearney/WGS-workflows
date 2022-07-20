#!/bin/bash
#SBATCH --mem-per-cpu=32G

module load Java/11.0.8

# Old file for testing. Use cromwell_gcb_#####.sh for workflow purposes
cd /work/btk20/gatk-workflows

export SINGULARITY_CACHEDIR=/work/btk20/gatk-workflows/.singularity/cache
# Convert .fastq files to .ubam
#rm -r /nfs/cegs-ccgr/analyses/gatk-workflows/cromwell-executions/ConvertPairedFastQsToUnmappedBamWf/*
#java -Dconfig.file=no_sql.conf -jar cromwell-78.jar run -i seq-format-conversion/paired-fastq-to-unmapped-bam.inputs.json seq-format-conversion/paired-fastq-to-unmapped-bam.wdl

# Process data, produce .bam and .bai files for sample
cd inputs

SAMPLE_NAME="H06HDADXX130110"
GLOB_DIR="H06HDADXX130110"
SUFFIX=".unmapped.bam"

> $SAMPLE_NAME.bam-input.txt
cat <<EOT >> $SAMPLE_NAME.bam-input.txt
/work/btk20/gatk-workflows/cromwell-executions/ConvertPairedFastQsToUnmappedBamWf/$GLOB_DIR/call-PairedFastQsToUnmappedBAM/execution/$SAMPLE_NAME$SUFFIX
EOT

> $SAMPLE_NAME.hg38.wgs.inputs.json
cat <<EOT >> $SAMPLE_NAME.hg38.wgs.inputs.json
{
  "PreProcessingForVariantDiscovery_GATK4.sample_name": "H06HDADXX130110",
  "PreProcessingForVariantDiscovery_GATK4.ref_name": "hg38",
  "PreProcessingForVariantDiscovery_GATK4.flowcell_unmapped_bams_list": "/work/btk20/gatk-workflows/inputs/$SAMPLE_NAME.bam-input.txt",
  "PreProcessingForVariantDiscovery_GATK4.unmapped_bam_suffix": ".unmapped.bam",
  "PreProcessingForVariantDiscovery_GATK4.ref_dict": "/work/btk20/gatk-workflows/genomes/hg38_genome/hg38.dict",
  "PreProcessingForVariantDiscovery_GATK4.ref_fasta": "/work/btk20/gatk-workflows/genomes/hg38_genome/hg38.fa",
  "PreProcessingForVariantDiscovery_GATK4.ref_fasta_index": "/work/btk20/gatk-workflows/genomes/hg38_genome/hg38.fa.fai",
  "PreProcessingForVariantDiscovery_GATK4.ref_alt": "/work/btk20/gatk-workflows/genomes/hg38_genome/Homo_sapiens_assembly38.fasta.64.alt",
  "PreProcessingForVariantDiscovery_GATK4.ref_sa": "/work/btk20/gatk-workflows/genomes/hg38_genome/hg38.fa.sa",
  "PreProcessingForVariantDiscovery_GATK4.ref_amb": "/work/btk20/gatk-workflows/genomes/hg38_genome/hg38.fa.amb",
  "PreProcessingForVariantDiscovery_GATK4.ref_bwt": "/work/btk20/gatk-workflows/genomes/hg38_genome/hg38.fa.bwt",
  "PreProcessingForVariantDiscovery_GATK4.ref_ann": "/work/btk20/gatk-workflows/genomes/hg38_genome/hg38.fa.ann",
  "PreProcessingForVariantDiscovery_GATK4.ref_pac": "/work/btk20/gatk-workflows/genomes/hg38_genome/hg38.fa.pac",

  "PreProcessingForVariantDiscovery_GATK4.dbSNP_vcf": "/work/btk20/gatk-workflows/genomes/hg38_genome/Homo_sapiens_assembly38.dbsnp138.vcf",
  "PreProcessingForVariantDiscovery_GATK4.dbSNP_vcf_index": "/work/btk20/gatk-workflows/genomes/hg38_genome/Homo_sapiens_assembly38.dbsnp138.vcf.idx",
  "PreProcessingForVariantDiscovery_GATK4.known_indels_sites_VCFs": [
    "/work/btk20/gatk-workflows/genomes/hg38_genome/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz",
    "/work/btk20/gatk-workflows/genomes/hg38_genome/Homo_sapiens_assembly38.known_indels.vcf.gz"
  ],
  "PreProcessingForVariantDiscovery_GATK4.known_indels_sites_indices": [
    "/work/btk20/gatk-workflows/genomes/hg38_genome/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz.tbi",
    "/work/btk20/gatk-workflows/genomes/hg38_genome/Homo_sapiens_assembly38.known_indels.vcf.gz.tbi"
  ]
}
EOT

cd /work/btk20/gatk-workflows
java -Dconfig.file=no_sql.conf -jar cromwell-78.jar run -i inputs/$SAMPLE_NAME.hg38.wgs.inputs.json gatk4-data-processing-2.1.1/processing-for-variant-discovery-gatk4.wdl

# Variant calling, produce .gvcf
#java -Dconfig.file=my.conf -jar cromwell-78.jar run -i gatk4-germline-snps-indels/haplotypecaller-gvcf-gatk4.hg38.wgs.inputs.json gatk4-germline-snps-indels/haplotypecaller-gvcf-gatk4.wdl

#java -Dconfig.file=no_sql.conf -jar cromwell-78.jar run -i gatk4-genome-processing-pipeline-1.3.0/WholeGenomeGermlineSingleSample.inputs.json gatk4-genome-processing-pipeline-1.3.0/WholeGenomeGermlineSingleSample.wdl
