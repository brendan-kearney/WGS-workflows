#!/bin/bash

cd /nfs/cegs-ccgr/data/raw/Crawford_7515_220304B6

#declare -a sample_names=("S18_S18" "S19_S19" "S20_S20" "S21_S21" "S22_S22" "S23_S23" "S24_S24" "S25_S25")

#declare -a sample_rename=("scaProband_156" "scaProband_191" "scaProband_193" "scaProband_197" "211Mother_206" "211Sister_207" "scaProband_208" "scaProband_211")

declare -a sample_names=("S23_S23")
declare -a sample_rename=("211Sister_207")

COUNTER=0

for i in "${sample_names[@]}"
do
	echo ${sample_rename[$COUNTER]}"_R2.fastq.gz"
	cat "7515_"$i"_L001_R1_001.fastq.gz" "7515_"$i"_L002_R1_001.fastq.gz" "7515_"$i"_L003_R1_001.fastq.gz" "7515_"$i"_L004_R1_001.fastq.gz" > ${sample_rename[$COUNTER]}"_R1.fastq.gz"
	cat "7515_"$i"_L001_R2_001.fastq.gz" "7515_"$i"_L002_R2_001.fastq.gz" "7515_"$i"_L003_R2_001.fastq.gz" "7515_"$i"_L004_R2_001.fastq.gz" > ${sample_rename[$COUNTER]}"_R2.fastq.gz"
	(( COUNTER++ ))
done

