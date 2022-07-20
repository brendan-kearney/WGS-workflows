#!/bin/bash
#SBATCH --mem-per-cpu=32G
#SBATCH --array=1-1%1
#SBATCH --job-name=fastq_ubam
module load Java/11.0.8

# Run https://github.com/gatk-workflows/seq-format-conversion .wdl script to convert .fastq inputs into a .u.bam file ready for alignment.
# Builds an input config file based on paired-fastq-to-unmapped-bam.inputs.json template.
# SBATCH --array NEEDS to be changed based on number of samples being ran at once. Currently=1
# Library name, platform unit, run date, platform name, sequencing center are required inputs, but not used for analysis.
# If known, those should be changed from defaults seen here.

# Place where fastq inputs are stored. 
SAMPLEDIR=/nfs/cegs-ccgr/data/raw/Crawford_7515_220304B6/

# Work space. Needs a decent amount of storage to run whole genome analysis
WORKDIR=/work/btk20/gatk-workflows
cd $WORKDIR

export SINGULARITY_CACHEDIR=$WORKDIR/.singularity/cache

# Text files of sample names. Use whatever format of sample names based on output of concat_fastqs.sh, listed one sample per line.
readarray -t SAMPLES < $WORKDIR/gcb_samples_rerun.txt
FILENAME=${SAMPLES[(($SLURM_ARRAY_TASK_ID - 1))]}

cd inputs

R1_SUFFIX="_R1.fastq.gz"
R2_SUFFIX="_R2.fastq.gz"

# Build input file for each sample. I used two variables (R1/R2_SUFFIX) to match the naming of the .fastq files.
# Should be changed to match your format
# The rest of the lines are throwaway lines but should be updated if sequencing info is known for clarity.
> $FILENAME.format-conversion.json
cat <<EOT >> $FILENAME.format-conversion.json
{
  "ConvertPairedFastQsToUnmappedBamWf.readgroup_name": "$FILENAME",
  "ConvertPairedFastQsToUnmappedBamWf.sample_name": "$FILENAME",
  "ConvertPairedFastQsToUnmappedBamWf.fastq_1": "$SAMPLEDIR$FILENAME$R1_SUFFIX",
  "ConvertPairedFastQsToUnmappedBamWf.fastq_2": "$SAMPLEDIR$FILENAME$R2_SUFFIX",
  "ConvertPairedFastQsToUnmappedBamWf.library_name": "Solexa-NA12878",
  "ConvertPairedFastQsToUnmappedBamWf.platform_unit": "H06HDADXX130110.2.ATCACGAT",
  "ConvertPairedFastQsToUnmappedBamWf.run_date": "2016-09-01T02:00:00+0200",
  "ConvertPairedFastQsToUnmappedBamWf.platform_name": "illumina",
  "ConvertPairedFastQsToUnmappedBamWf.sequencing_center": "BI",

  "ConvertPairedFastQsToUnmappedBamWf.make_fofn": true  
}
EOT

# Execute .wdl file for each sample. Output is found in cromwell-executions/ConvertPairedFastQsToUnmappedBamWf,
# stored as a random glob directory. I rename these globs in the next script (cromwell_gcb_PreProcessing)
cd ..
java -Dconfig.file=no_sql.conf -jar cromwell-78.jar run -i inputs/$FILENAME.format-conversion.json seq-format-conversion/paired-fastq-to-unmapped-bam.wdl
