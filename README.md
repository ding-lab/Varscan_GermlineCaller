# Varscan_GermlineCaller

Call germline variants using GATK4 HaplotypeCaller
Can operate on multiple regions with a passed CHRLIST file

For single region, calls look like,:
    samtools mpileup -q 1 -Q 13 BAM | java -jar VarScan.jar mpileup2snp - --min-coverage 3 --min-var-freq 0.10 --p-value 0.10 --strand-filter 1 --output-vcf 1 
    samtools mpileup -q 1 -Q 13 BAM | java -jar VarScan.jar mpileup2indel - --min-coverage 3 --min-var-freq 0.10 --p-value 0.10 --strand-filter 1 --output-vcf 1 

For multiple regions (specified by -c CHRLIST), calls are like,
  for CHR in CHRLIST
    samtools mpileup -q 1 -Q 13 -r CHR BAM | java -jar VarScan.jar mpileup2snp - --min-coverage 3 --min-var-freq 0.10 --p-value 0.10 --strand-filter 1 --output-vcf 1 
  bcftools concat -o Varscan.snp.Final.vcf
  bcftools concat -o Varscan.indel.Final.vcf

## CHRLIST

CHRLIST is a file which can take arbitrary genomic regions in a format accepted by GATK HaplotypeCaller.
Generally, a listing of all chromosomes will suffice

## Arguments

* reference: Reference FASTA
* bam: Input BAM/CRAM
* chrlist: List of genomic regions
* njobs: 'Number of jobs to run in parallel mode'
* dryrun: 'Print out commands but do not execute, for testing only'
* index_output: 'Compress and index output VCF files'
* finalize: 'Compress intermediate data and logs'
* MP_ARGS: samtools mpileup arguments
* JAVA_ARGS: java arguments
* VS_ARGS: Varscan mpileup2indel and mpileup2snp arguments

## Testing

`./testing` directory has demo data which can be quickly used to exercise different parts of pipeline
Pipeline can be called in 3 contexts:
* Direct, but entering docker container and running from command line 
* Docker, by invoking a docker run with the requested command
* CWL, using CWL workflow manager
  * Rabix and cromwell are supported

## Production

Setting `finalize` parameter to `true` will compress all intermediate files and logs

## Author

Matthew Wyczalkowski <m.wyczalkowski@wustl.edu>

