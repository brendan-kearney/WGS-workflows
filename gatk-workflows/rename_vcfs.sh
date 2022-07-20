#!/bin/bash
#SBATCH --mem-per-cpu=32G
#SBATCH --array=1-1%1
#SBATCH --job-name=rename_dirs
module load Java/11.0.8

cd /work/btk20/gatk-workflows

export SINGULARITY_CACHEDIR=/work/btk20/gatk-workflows/.singularity/cache

#Rename seq-format-conversion output dirs based on sample name
cd cromwell-executions/HaplotypeCallerGvcf_GATK4/
for dir in */
do
	cd /work/btk20/gatk-workflows/cromwell-executions/HaplotypeCallerGvcf_GATK4
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
	cd /work/btk20/gatk-workflows/cromwell-executions/HaplotypeCallerGvcf_GATK4
	mv "$dir" "$sampleName4"
done
