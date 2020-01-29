#/bin/bash

read -r -d '' USAGE <<'EOF'
Run Varscan germline variant caller

Usage: process_sample.sh [options] reference.fa input.bam 
 
Options:
-h: Print this help message
-d : Dry run - output commands but do not execute them
-C MP_ARGS : pass args to `samtools mpileup`
-D JAVA_ARGS : pass args to java
-E VS_ARGS: pass args to mpileup2indel and mpileup2snp
-L INPUT_INTERVAL : One or more genomic intervals over which to operate
  This is passed verbatim to samtools mpileup -r INPUT_INTERVAL
-l INTERVAL_LABEL : A short label for interval, used for filenames.  Default is INPUT_INTERVAL
-o OUTD : Output directory [ ./output ]
-N : Write output of samtools mpileup to intermediate file rather than use pipes

General format of command is,
samtools mpileup -q 1 -Q 13 BAM | java -jar VarScan.jar mpileup2indel - --min-coverage 3 --min-var-freq 0.10 --p-value 0.10 --strand-filter 1 --output-vcf 1 

Output filenames:
    OUTD/Varscan.snp.XXX.vcf
    OUTD/Varscan.indel.XXX.vcf
where XXX is given by INTERVAL_LABEL
EOF

source /opt/Varscan_GermlineCaller/src/utils.sh
SCRIPT=$(basename $0)

JAR="/opt/VarScan.v2.3.8.jar"

# Set defaults
OUTD="./output"
OUTVCF="final.SV.WGS.vcf"

# http://wiki.bash-hackers.org/howto/getopts_tutorial
while getopts ":hdC:D:E:L:l:o:N" opt; do
  case $opt in
    h)
      echo "$USAGE"
      exit 0
      ;;
    d)  # binary argument
      DRYRUN=1
      ;;
    C) # value argument
      MP_ARGS="$MP_ARGS $OPTARG"
      ;;
    D) # value argument
      JAVA_ARGS="$JAVA_ARGS $OPTARG"
      ;;
    E) # value argument
      VS_ARGS="$VS_ARGS $OPTARG"
      ;;
    L) # value argument
      INPUT_INTERVAL="$OPTARG"
      ;;
    l) # value argument
      INTERVAL_LABEL="$OPTARG"
      ;;
    o) # value argument
      OUTD=$OPTARG
      ;;
    N)  # binary argument
      NO_PIPE=1
      ;;
    \?)
      >&2 echo "Invalid option: -$OPTARG"
      >&2 echo "$USAGE"
      exit 1
      ;;
    :)
      >&2 echo "Option -$OPTARG requires an argument."
      >&2 echo "$USAGE"
      exit 1
      ;;
  esac
done
shift $((OPTIND-1))


if [ "$#" -ne 2 ]; then
    >&2 echo Error: Wrong number of arguments
    >&2 echo "$USAGE"
    exit 1
fi

REF=$1
BAM=$2

confirm $BAM
confirm $REF

# IX forms part of suffix of output filename
# If INTERVAL_LABEL is given, IX takes that value
# otherwise, get value from INPUT_INTERVAL
if [ "$INTERVAL_LABEL" ]; then
    IX="$INTERVAL_LABEL"
else
    IX="$INPUT_INTERVAL"
fi

VARSCAN="/usr/bin/java $JAVA_ARGS -jar $JAR "
VS_ARGS="$VS_ARGS --min-coverage 3 --min-var-freq 0.10 --p-value 0.10 --strand-filter 1 --output-vcf 1"
MP_ARGS="$MP_ARGS -q 1 -Q 13"
SAMTOOLS="/opt/conda/bin/samtools"

if [ "$INPUT_INTERVAL" ]; then
    MP_ARGS="$MP_ARGS -r $INPUT_INTERVAL"
fi

mkdir -p $OUTD
test_exit_status

OUT_SNP="$OUTD/Varscan.snp.${IX}.vcf"
LOG_SNP="$OUTD/Varscan.snp.${IX}.log"
OUT_INDEL="$OUTD/Varscan.indel.${IX}.vcf"
LOG_INDEL="$OUTD/Varscan.indel.${IX}.log"

CMD1="$SAMTOOLS mpileup $MP_ARGS -f $REF $BAM" 
CMD2="$VARSCAN mpileup2snp - $VS_ARGS > $OUT_SNP 2> $LOG_SNP"
CMD3="$VARSCAN mpileup2snp - $VS_ARGS > $OUT_INDEL 2> $LOG_INDEL"

if [ $NO_PIPE ]; then
    OUT1="$OUTD/mpileup.${IX}.out"
    CMD="$CMD1 > $OUT1"
    >&2 echo No pipe: writing to $OUT1
    run_cmd "$CMD" $DRYRUN
    
    CMD="cat $OUT1 | $CMD2 "
    run_cmd "$CMD" $DRYRUN
    
    CMD="cat $OUT1 | $CMD3 "
    run_cmd "$CMD" $DRYRUN

else
    >&2 echo Running with process substitution
# https://unix.stackexchange.com/questions/40277/is-there-a-way-to-pipe-the-output-of-one-program-into-two-other-programs
    CMD="$CMD1 | tee >($CMD2) | $CMD3"
    run_cmd "$CMD" $DRYRUN
fi

#    shell: "samtools mpileup -q 1 -Q 13 -f {input.genome_fa} -r {params.chr} {input.bam} | varscan mpileup2snp - --min-coverage 3 --min-var-freq 0.10 --p-value 0.10 --strand-filter 1 --output-vcf 1 > {output} 2>{log}"
#    shell: "samtools mpileup -q 1 -Q 13 -f {input.genome_fa} -r {params.chr} {input.bam} | varscan mpileup2indel - --min-coverage 3 --min-var-freq 0.10 --p-value 0.10 --strand-filter 1 --output-vcf 1 > {output} 2>{log}"


# Run SelectVariants
CMD2A="$GATK SelectVariants -R $REF -V $OUT1 -O $OUT2A -select-type SNP -select-type MNP $SV_SNP_ARGS"
CMD2B="$GATK SelectVariants -R $REF -V $OUT1 -O $OUT2B -select-type INDEL $SV_INDEL_ARGS"
run_cmd "$CMD2A" $DRYRUN
run_cmd "$CMD2B" $DRYRUN

>&2 echo $SCRIPT success.
>&2 echo Written SNP to $OUT2A 
>&2 echo Written INDEL to $OUT2B
