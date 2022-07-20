#!/bin/bash

#SBATCH --mem-per-cpu=32G
#SBATCH --job-name=geno_vcfs

# Script for merging, genotyping, and filtering wgs variants from gatk .wdl vcf files. If reference is not hg38, hard filtering is used (bottom of file)

# Reference files: https://console.cloud.google.com/storage/browser/genomics-public-data/resources/broad/hg38/v0;tab=objects?pli=1&prefix=&forceOnObjectsSortingFiltering=false

# Samples in cohort. Entered 
SAMPLE1=ahcNegative_89
SAMPLE2=ahcNegative_90
SAMPLE3=89_90Parent_91
SAMPLE4=89_90Parent_92
COHORTNAME=89_90cohort

GATK4_DIST=/hpc/group/allenlab/btk20/software/gatk-4.2.6.1/gatk-package-4.2.6.1-local.jar
WORKDIR=/work/btk20/gatk-workflows
GENOMEDIR=/work/btk20/genomes/hg38

#Combine GVCF files (if necessary)
# Add --variant lines for each sample in cohort
java -jar $GATK4_DIST CombineGVCFs \
	-R $GENOMEDIR/hg38.fa \
	--variant $WORKDIR/cromwell-executions/HaplotypeCallerGvcf_GATK4/$SAMPLE1/call-HaplotypeCaller/shard-0/execution/$SAMPLE1.hg38.g.vcf.gz \
	--variant $WORKDIR/cromwell-executions/HaplotypeCallerGvcf_GATK4/$SAMPLE2/call-HaplotypeCaller/shard-0/execution/$SAMPLE2.hg38.g.vcf.gz \
	--variant $WORKDIR/cromwell-executions/HaplotypeCallerGvcf_GATK4/$SAMPLE3/call-HaplotypeCaller/shard-0/execution/$SAMPLE3.hg38.g.vcf.gz \
	--variant $WORKDIR/cromwell-executions/HaplotypeCallerGvcf_GATK4/$SAMPLE4/call-HaplotypeCaller/shard-0/execution/$SAMPLE4.hg38.g.vcf.gz \
	-O $WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.g.vcf.gz

# Perform joint genotyping on one or more samples pre-called with HaplotypeCaller
java -jar $GATK4_DIST GenotypeGVCFs \
	-R $GENOMEDIR/hg38.fa \
	-V $WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.g.vcf.gz \
	-O $WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.genotyped.vcf.gz

rm $WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.g.vcf.gz

cd $GENOMEDIR
#Calculate VQSLOD tranches for indels using VariantRecalibrator
java -Xms4G -Xmx32G -jar $GATK4_DIST VariantRecalibrator \
	-V $WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.genotyped.vcf.gz \
	--trust-all-polymorphic \
	-tranche 100.0 -tranche 99.95 -tranche 99.9 -tranche 99.5 -tranche 99.0 -tranche 97.0 -tranche 96.0 -tranche 95.0 -tranche 94.0 -tranche 93.5 -tranche 93.0 -tranche 92.0 -tranche 91.0 -tranche 90.0 \
	-an FS -an ReadPosRankSum -an MQRankSum -an QD -an SOR -an DP \
	-mode INDEL \
	--max-gaussians 4 \
	-resource:mills,known=false,training=true,truth=true,prior=12 Mills_and_1000G_gold_standard.indels.hg38.vcf.gz \
	-resource:axiomPoly,known=false,training=true,truth=false,prior=10 Axiom_Exome_Plus.genotypes.all_populations.poly.hg38.vcf.gz \
	-resource:dbsnp,known=true,training=false,truth=false,prior=2 Homo_sapiens_assembly38.dbsnp138.vcf \
	-O $WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.indels.recal \
	--tranches-file $WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.indels.tranches

#Calculate VQSLOD tranches for SNPs using VariantRecalibrator
java -Xms4G -Xmx32G -jar $GATK4_DIST VariantRecalibrator \
	-V $WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.genotyped.vcf.gz \
	--trust-all-polymorphic \
	-tranche 100.0 -tranche 99.95 -tranche 99.9 -tranche 99.8 -tranche 99.6 -tranche 99.5 -tranche 99.4 -tranche 99.3 -tranche 99.0 -tranche 98.0 -tranche 97.0 -tranche 90.0 \
	-an QD -an MQRankSum -an ReadPosRankSum -an FS -an MQ -an SOR -an DP \
	-mode SNP \
	--max-gaussians 6 \
	-resource:hapmap,known=false,training=true,truth=true,prior=15 hapmap_3.3.hg38.vcf.gz \
	-resource:omni,known=false,training=true,truth=true,prior=12 1000G_omni2.5.hg38.vcf.gz \
	-resource:1000G,known=false,training=true,truth=false,prior=10 1000G_phase1.snps.high_confidence.hg38.vcf.gz \
	-resource:dbsnp,known=true,training=false,truth=false,prior=7 Homo_sapiens_assembly38.dbsnp138.vcf \
	-O $WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.snp.recal \
	--tranches-file $WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.snp.tranches


#Filter indels on VQSLOD using ApplyVQSR
java -Xms4G -Xmx32G -jar $GATK4_DIST ApplyVQSR \
	-V $WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.genotyped.vcf.gz \
	--recal-file $WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.indels.recal \
	--tranches-file $WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.indels.tranches \
	--truth-sensitivity-filter-level 99.7 \
	--create-output-variant-index true \
	--mode INDEL \
	-O $WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.indel.recalibrated.vcf.gz

#Filter SNPs on VQSLOD using ApplyVQSR given the indel-filtered callset
java -Xms4G -Xmx32G -jar $GATK4_DIST ApplyVQSR \
	-V $WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.indel.recalibrated.vcf.gz \
	--recal-file $WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.snp.recal \
	--tranches-file $WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.snp.tranches \
	--truth-sensitivity-filter-level 99.7 \
        --create-output-variant-index true \
        --mode SNP \
	-O $WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.recalibrated.vcf.gz

cd $WORKDIR/exomiser-runs/genotype_$COHORTNAME
rm $COHORTNAME.indels.recal
rm $COHORTNAME.indels.recal.idx
rm $COHORTNAME.indels.tranches
rm $COHORTNAME.snp.recal
rm $COHORTNAME.snp.recal.idx
rm $COHORTNAME.snp.tranches
rm $COHORTNAME.indel.recalibrated.vcf.gz
rm $COHORTNAME.indel.recalibrated.vcf.gz.tbi
rm $COHORTNAME.genotyped.vcf.gz
rm $COHORTNAME.genotyped.vcf.gz.tbi

# ~~~~~~~~~~~~~~~~ Manual hard filtering (hg19)
## Subset to SNPs and indels-only callsets
#java -jar $GATK4_DIST SelectVariants \
#	-V $WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.genotyped.vcf.gz \
#	-select-type SNP \
#	-O $WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.snps.vcf.gz

#java -jar $GATK4_DIST SelectVariants \
#        -V $WORKDIR/exomiser-runs/genotyped_samples/genotype_$COHORTNAME/$COHORTNAME.genotyped.vcf.gz \
#        -select-type INDEL \
#        -O $WORKDIR/exomiser-runs/genotyped_samples/genotype_$COHORTNAME/$COHORTNAME.indels.vcf.gz

#rm $WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.genotyped.vcf.gz
#rm $WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.genotyped.vcf.gz.tbi

## Hard filter SNPs and INDELS separately
#java -jar $GATK4_DIST VariantFiltration \
#	-V $WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.snps.vcf.gz \
#	-filter "QD < 2.0" --filter-name "QD2" \
#	-filter "QUAL < 30.0" --filter-name "QUAL30" \
#	-filter "SOR > 3.0" --filter-name "SOR3" \
#	-filter "FS > 60.0" --filter-name "FS60" \
#	-filter "MQ < 40.0" --filter-name "MQ40" \
#	-O $WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.snp_filtered.vcf.gz

#rm $WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.snps.vcf.gz
#rm $WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.snps.vcf.gz.tbi

#java -jar $GATK4_DIST VariantFiltration \
#	-V $WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.indels.vcf.gz \
#	-filter "QD < 2.0" --filter-name "QD2" \
#        -filter "QUAL < 30.0" --filter-name "QUAL30" \
#        -filter "FS > 200.0" --filter-name "FS200" \
#	-O $WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.indel_filtered.vcf.gz

#rm $WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.indels.vcf.gz
#rm $WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.indels.vcf.gz.tbi

## Uses conda picard package to merge snps/indels
#picard MergeVcfs \
#	I=$WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.snp_filtered.vcf.gz \
#	I=$WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.indel_filtered.vcf.gz \
#	O=$WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.merged_filtered.vcf.gz

#rm $WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.snp_filtered.vcf.gz
#rm $WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.snp_filtered.vcf.gz.tbi
#rm $WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.indel_filtered.vcf.gz
#rm $WORKDIR/exomiser-runs/genotype_$COHORTNAME/$COHORTNAME.indel_filtered.vcf.gz.tbi
