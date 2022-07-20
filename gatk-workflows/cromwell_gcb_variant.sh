#!/bin/bash
#SBATCH --mem-per-cpu=32G
#SBATCH --array=1-2%2
#SBATCH --job-name=crom_var
module load Java/11.0.8

# Run https://github.com/gatk-workflows/gatk4-germline-snps-indels to convert .bam file to 
# The .json requires a lot of hg38 reference files. Most can be found https://console.cloud.google.com/storage/browser/genomics-public-data/resources/broad/hg38/v0;tab=objects?prefix=&forceOnObjectsSortingFiltering=false
# https://console.cloud.google.com/storage/browser/gatk-test-data/intervals;tab=objects?prefix=&forceOnObjectsSortingFiltering=false

# Work space. Needs a decent amount of storage
WORKDIR=/work/btk20/gatk-workflows
cd $WORKDIR

# Genome reference file directory. Most can be downloaded from link above.
GENOMEDIR=/work/btk20/genomes/hg38

export SINGULARITY_CACHEDIR=/work/btk20/gatk-workflows/.singularity/cache

#Rename PreProcessing output dirs based on sample name
cd cromwell-executions/PreProcessingForVariantDiscovery_GATK4
for dir in */
do
	cd $WORKDIR/cromwell-executions/PreProcessingForVariantDiscovery_GATK4
	dir=${dir%*/}
	cd $dir/call-GatherBamFiles/execution
	BAMFILE=$(find . -type f -name '*.hg38.bai')
	trimmed="$(echo $BAMFILE | cut -c 3-)"
	sampleName1=${trimmed%.*}
	sampleName2=${sampleName1%.*}
	cd $WORKDIR/cromwell-executions/PreProcessingForVariantDiscovery_GATK4
	mv "$dir"/call-GatherBamFiles/execution/$trimmed /work/btk20/data_storage/finished_bams
	mv "$dir"/call-GatherBamFiles/execution/$sampleName2.bai /work/btk20/data_storage/finished_bams
done

readarray -t SAMPLES < $WORKDIR/gcb_samples_rerun.txt
FILENAME=${SAMPLES[(($SLURM_ARRAY_TASK_ID - 1))]}

#Create variant calling .json file for each sample
cd $WORKDIR/inputs
> $FILENAME.haplotypecaller-inputs.json
cat <<EOT >> $FILENAME.haplotypecaller-inputs.json
{
  "HaplotypeCallerGvcf_GATK4.input_bam": "$WORKDIR/cromwell-executions/PreProcessingForVariantDiscovery_GATK4/$FILENAME/call-GatherBamFiles/execution/$FILENAME.bam",
  "HaplotypeCallerGvcf_GATK4.input_bam_index": "$WORKDIR/cromwell-executions/PreProcessingForVariantDiscovery_GATK4/$FILENAME/call-GatherBamFiles/execution/$FILENAME.bam.bai",
  "HaplotypeCallerGvcf_GATK4.ref_dict": "$GENOMEDIR/hg38.dict",
  "HaplotypeCallerGvcf_GATK4.ref_fasta": "$GENOMEDIR/hg38.fa",
  "HaplotypeCallerGvcf_GATK4.ref_fasta_index": "$GENOMEDIR/hg38.fa.fai",

  "HaplotypeCallerGvcf_GATK4.scattered_calling_intervals_list": "$GENOMEDIR/hg38_wgs_custom_intervals.txt"
}
EOT

# Run haplotypercaller .wdl script
cd $WORKDIR
java -Dconfig.file=no_sql.conf -jar cromwell-78.jar run -i inputs/$FILENAME.haplotypecaller-inputs.json gatk4-germline-snps-indels/haplotypecaller-gvcf-gatk4.wdl

#Rename GATK4 HaplotypeCaller output dirs based on sample name
cd cromwell-executions/HaplotypeCallerGvcf_GATK4/
for dir in */
do
	cd $WORKDIR/cromwell-executions/HaplotypeCallerGvcf_GATK4
	dir=${dir%*/}
	cd $dir/call-HaplotypeCaller/shard-0/execution
	vcfFILE=$(find . -type f -name '*.g.vcf.gz')
	trimmed="$(echo $vcfFILE | cut -c 3-)"
	sampleName1=${trimmed%.*}
	sampleName2=${sampleName1%.*}
	sampleName3=${sampleName2%.*}
	sampleName4=${sampleName3%.*}
	echo $dir
	echo "$sampleName4"
	cd $WORKDIR/cromwell-executions/HaplotypeCallerGvcf_GATK4
	mv "$dir" "$sampleName4"
done
