# WGS-workflows
Bash scripts for running whole genome pipeline for rare variant discovery. Uses Singularity to run Cromwell on a HPC system.

Requires cromwell-##.jar in folder gatk-workflows
https://github.com/broadinstitute/cromwell/releases

General order of workflows:
1. concat_fastqs.sh
2. cromwell_gcb_seqFormat.sh
3. cromwell_gcb_PreProcessing.sh
4. cromwell_gcb_variant.sh
5. genotypeGVCFs.sh
6. Exomiser analysis
