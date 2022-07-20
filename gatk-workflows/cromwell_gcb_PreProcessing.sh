#!/bin/bash
#SBATCH --mem-per-cpu=32G
#SBATCH --array=1-1%1
#SBATCH --job-name=crom_ali
module load Java/11.0.8

# Run  https://github.com/gatk-workflows/gatk4-data-processing to convert uBAM sample files to aligned BAM output.
# SBATCH --array NEEDS to be changed based on number of samples being ran at once. Currently=1
# Script requires two files - a text input file and the standard .json config
# This ubam input file is just one line and is handled in this script.
# The .json requires a lot of hg38 reference files. Most can be found https://console.cloud.google.com/storage/browser/genomics-public-data/resources/broad/hg38/v0;tab=objects?prefix=&forceOnObjectsSortingFiltering=false

# Work space. Needs a decent amount of storage
WORKDIR=/work/btk20/gatk-workflows
cd $WORKDIR

# Genome reference file directory. Most can be downloaded from link above.
GENOMEDIR=/work/btk20/genomes/hg38
export SINGULARITY_CACHEDIR=/work/btk20/gatk-workflows/.singularity/cache

#Rename seq-format-conversion output dirs based on sample name. Assumes output from cromwell_gcb_seqFormat.sh is untouched globs.
cd cromwell-executions/ConvertPairedFastQsToUnmappedBamWf
for dir in */
do
	cd $WORKDIR/cromwell-executions/ConvertPairedFastQsToUnmappedBamWf
	dir=${dir%*/}
	cd $dir/call-PairedFastQsToUnmappedBAM/execution
	uBAMFILE=$(find . -type f -name '*.unmapped.bam')
	trimmed="$(echo $uBAMFILE | cut -c 3-)"
	sampleName1=${trimmed%.*}
	sampleName2=${sampleName1%.*}
	echo $dir
	echo "$sampleName2"
	cd $WORKDIR/cromwell-executions/ConvertPairedFastQsToUnmappedBamWf
	mv "$dir" "$sampleName2"
done

# List of sample inputs for this run
readarray -t SAMPLES < $WORKDIR/gcb_samples_rerun.txt
FILENAME=${SAMPLES[(($SLURM_ARRAY_TASK_ID - 1))]}

# CREATE .ubam text input file (contains just one line with location of ubam file)
cd inputs
SUFFIX=".unmapped.bam"
> $FILENAME.bam-input.txt
cat <<EOT >> $FILENAME.bam-input.txt
$WORKDIR/cromwell-executions/ConvertPairedFastQsToUnmappedBamWf/$FILENAME/call-PairedFastQsToUnmappedBAM/execution/$FILENAME$SUFFIX
EOT

# CREATE PreProcessing .json file for each sample based on gatk template
> $FILENAME.hg38.wgs.inputs.json
cat <<EOT >> $FILENAME.hg38.wgs.inputs.json
{
  "PreProcessingForVariantDiscovery_GATK4.sample_name": "$FILENAME",
  "PreProcessingForVariantDiscovery_GATK4.ref_name": "hg38",
  "PreProcessingForVariantDiscovery_GATK4.flowcell_unmapped_bams_list": "$WORKDIR/$FILENAME.bam-input.txt",
  "PreProcessingForVariantDiscovery_GATK4.unmapped_bam_suffix": ".unmapped.bam",
  "PreProcessingForVariantDiscovery_GATK4.ref_dict": "$GENOMEDIR/hg38.dict",
  "PreProcessingForVariantDiscovery_GATK4.ref_fasta": "$GENOMEDIR/hg38.fa",
  "PreProcessingForVariantDiscovery_GATK4.ref_fasta_index": "$GENOMEDIR/hg38.fa.fai",
  "PreProcessingForVariantDiscovery_GATK4.ref_alt": "$GENOMEDIR/Homo_sapiens_assembly38.fasta.64.alt",
  "PreProcessingForVariantDiscovery_GATK4.ref_sa": "$GENOMEDIR/hg38.fa.sa",
  "PreProcessingForVariantDiscovery_GATK4.ref_amb": "$GENOMEDIR/hg38.fa.amb",
  "PreProcessingForVariantDiscovery_GATK4.ref_bwt": "$GENOMEDIR/hg38.fa.bwt",
  "PreProcessingForVariantDiscovery_GATK4.ref_ann": "$GENOMEDIR/hg38.fa.ann",
  "PreProcessingForVariantDiscovery_GATK4.ref_pac": "$GENOMEDIR/hg38.fa.pac",

  "PreProcessingForVariantDiscovery_GATK4.dbSNP_vcf": "$GENOMEDIR/Homo_sapiens_assembly38.dbsnp138.vcf",
  "PreProcessingForVariantDiscovery_GATK4.dbSNP_vcf_index": "$GENOMEDIR/Homo_sapiens_assembly38.dbsnp138.vcf.idx",
  "PreProcessingForVariantDiscovery_GATK4.known_indels_sites_VCFs": [
    "$GENOMEDIR/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz",
    "$GENOMEDIR/Homo_sapiens_assembly38.known_indels.vcf.gz"
  ],
  "PreProcessingForVariantDiscovery_GATK4.known_indels_sites_indices": [
    "$GENOMEDIR/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz.tbi",
    "$GENOMEDIR/Homo_sapiens_assembly38.known_indels.vcf.gz.tbi"
  ]
}
EOT

cd $WORKDIR

# RUN gatk PreProcessing, convert .ubam file into aligned and analysis-ready .bam
java -Dconfig.file=no_sql.conf -jar cromwell-78.jar run -i inputs/$FILENAME.hg38.wgs.inputs.json gatk4-data-processing-2.1.1/processing-for-variant-discovery-gatk4.wdl
