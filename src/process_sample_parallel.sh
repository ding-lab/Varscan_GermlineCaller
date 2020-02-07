#!/bin/bash

# Matthew Wyczalkowski <m.wyczalkowski@wustl.edu>
# https://dinglab.wustl.edu/

read -r -d '' USAGE <<'EOF'
Run Varscan germline caller, possibly for multiple intervals in parallel,
and generate one VCF file for SNVs and one for INDELs

Usage: 
  process_sample_parallel.sh [options] REF BAM

Output: 
    OUTD/Varscan.snp.Final.vcf
    OUTD/Varscan.indel.Final.vcf

Options:
-h : print usage information
-d : dry-run. Print commands but do not execute them
-1 : stop after iteration over CHRLIST
-c CHRLIST: File listing genomic intervals over which to operate
-j JOBS: if parallel run, number of jobs to run at any one time.  If 0, run sequentially.  Default: 4
-o OUTD: set output root directory.  Default ./output
-F : finalize run by compressing per-region output and logs
-I: Index output files.  Note that the VCF files will be compressed, end in .gz

The following arguments are passed to process_sample.sh directly:
-C MP_ARGS : pass args to `samtools mpileup`
-D JAVA_ARGS : pass args to java
-E VS_ARGS: pass args to mpileup2indel and mpileup2snp

For single region, calls look like,:
samtools mpileup -q 1 -Q 13 BAM | java -jar VarScan.jar mpileup2snp - --min-coverage 3 --min-var-freq 0.10 --p-value 0.10 --strand-filter 1 --output-vcf 1 
samtools mpileup -q 1 -Q 13 BAM | java -jar VarScan.jar mpileup2indel - --min-coverage 3 --min-var-freq 0.10 --p-value 0.10 --strand-filter 1 --output-vcf 1 

For multiple regions (specified by -c CHRLIST), calls are like,
  for CHR in CHRLIST
    samtools mpileup -q 1 -Q 13 -r CHR BAM | java -jar VarScan.jar mpileup2snp - --min-coverage 3 --min-var-freq 0.10 --p-value 0.10 --strand-filter 1 --output-vcf 1 

  bcftools concat -o Varscan.snp.Final.vcf
  bcftools concat -o Varscan.indel.Final.vcf

CHRLIST is a file listing genomic intervals over which to operate, with each
line passed to `gatk HaplotypeCaller -L`. 

In general, if CHRLIST is defined, jobs will be submitted in parallel mode: use
GNU parallel to loop across all entries in CHRLIST, running -j JOBS at a time,
and wait until all jobs completed.  Output logs written to OUTD/logs/Varscan.$CHR.log
Parallel mode can be disabled with -j 0.

EOF

source /opt/Varscan_GermlineCaller/src/utils.sh
SCRIPT=$(basename $0)

# Background on `parallel` and details about blocking / semaphores here:
#    O. Tange (2011): GNU Parallel - The Command-Line Power Tool,
#    ;login: The USENIX Magazine, February 2011:42-47.
# [ https://www.usenix.org/system/files/login/articles/105438-Tange.pdf ]

# set defaults
NJOBS=4
DO_PARALLEL=0
OUTD="./output"
PROCESS="/opt/Varscan_GermlineCaller/src/process_sample.sh"
BCFTOOLS="/opt/conda/bin/bcftools"
BGZIP="/opt/conda/bin/bgzip"

# http://wiki.bash-hackers.org/howto/getopts_tutorial
while getopts ":hd1c:j:o:C:D:E:FI" opt; do
  case $opt in
    h)
      echo "$USAGE"
      exit 0
      ;;
    d)  # example of binary argument
      >&2 echo "Dry run" 
      DRYRUN=1
      ;;
    1) 
      JUSTONE=1
      ;;
    c) 
      CHRLIST_FN=$OPTARG
      DO_PARALLEL=1
      ;;
    j) 
      NJOBS=$OPTARG  
      ;;
    o) 
      OUTD=$OPTARG
      ;;
    C) 
      PS_ARGS="$PS_ARGS -C \"$OPTARG\""
      ;;
    D) 
      PS_ARGS="$PS_ARGS -D \"$OPTARG\""
      ;;
    E) 
      PS_ARGS="$PS_ARGS -E \"$OPTARG\""
      ;;
    F) 
      FINALIZE=1
      ;;
    I)  # binary argument
      DO_INDEX=1
      ;;
    \?)
      >&2 echo "$SCRIPT: ERROR: Invalid option: -$OPTARG"
      >&2 echo "$USAGE"
      exit 1
      ;;
    :)
      >&2 echo "$SCRIPT: ERROR: Option -$OPTARG requires an argument."
      >&2 echo "$USAGE"
      exit 1
      ;;
  esac
done
shift $((OPTIND-1))

if [ "$#" -ne 2 ]; then
    >&2 echo ERROR: Wrong number of arguments
    >&2 echo "$USAGE"
    exit 1
fi

REF=$1;   confirm $REF
BAM=$2;   confirm $BAM

# Read CHRLIST_FN to get list of elements
# These were traditionally individual chromosomes, 
# but can be other regions as well
if [ $CHRLIST_FN ]; then
    confirm $CHRLIST_FN
    CHRLIST=$(cat $CHRLIST_FN)
    # Will need to merge multiple VCFs
else
    # Will not need to merge multiple VCFs
    CHRLIST="Final"
    NO_CHRLIST=1
fi
    
# Output, tmp, and log files go here
mkdir -p $OUTD

# Per-region output goes here
if [ ! "$NO_CHRLIST" ]; then
    OUTDR="$OUTD/regions"
    mkdir -p $OUTDR
fi

# CHRLIST newline-separated list of regions passed to samtools mpileup -r
LOGD="$OUTD/logs"
mkdir -p $LOGD

NOW=$(date)
MYID=$(date +%Y%m%d%H%M%S)

if [ $NJOBS == "0" ]; then 
    DO_PARALLEL=0
fi

if [ $DO_PARALLEL == 1 ]; then
    >&2 echo [ $NOW ]: Parallel run 
    >&2 echo . 	  Looping over $CHRLIST
    >&2 echo . 	  Parallel jobs: $NJOBS
    >&2 echo . 	  Log files: $LOGD
else
    >&2 echo [ $NOW ]: Single region at a time
    >&2 echo . 	  Looping over $CHRLIST
    >&2 echo . 	  Log files: $LOGD
fi

for CHR in $CHRLIST; do
    NOW=$(date)
    >&2 echo \[ $NOW \] : Processing $CHR

    STDOUT_FN="$LOGD/Varscan_GermlineCaller.$CHR.out"
    STDERR_FN="$LOGD/Varscan_GermlineCaller.$CHR.err"

    # core call to process_sample.sh
    if [ "$NO_CHRLIST" ]; then
        if [ $DO_INDEX ]; then 
            XARG="-I"
        fi
        CMD="$PROCESS $PS_ARGS $XARGS -o $OUTD -l Final $REF $BAM > $STDOUT_FN 2> $STDERR_FN"
    else
        # if looping across regions, always index so that bcftools works
        CMD="$PROCESS $PS_ARGS -I -o $OUTDR -L $CHR $REF $BAM > $STDOUT_FN 2> $STDERR_FN"
    fi

    if [ $DO_PARALLEL == 1 ]; then
        JOBLOG="$LOGD/Varscan_GermlineCaller.$CHR.log"
        CMD=$(echo "$CMD" | sed 's/"/\\"/g' )   # This will escape the quotes in $CMD
        CMD="parallel --semaphore -j$NJOBS --id $MYID --joblog $JOBLOG --tmpdir $LOGD \"$CMD\" "
    fi

    run_cmd "$CMD" $DRYRUN

    if [ "$JUSTONE" ]; then
        >&2 echo Exiting after one
        break
    fi
done

if [ $DO_PARALLEL == 1 ]; then
    # this will wait until all jobs completed
    CMD="parallel --semaphore --wait --id $MYID"
    run_cmd "$CMD" $DRYRUN
fi

OUT_SNP="$OUTD/Varscan.snp.Final.vcf"
OUT_INDEL="$OUTD/Varscan.indel.Final.vcf"
# Now merge if we are looping over regions in CHRLIST
# Merged output will have same filename as if CHR were "Final"
# testing for globs from https://stackoverflow.com/questions/2937407/test-whether-a-glob-has-any-matches-in-bash
if [ ! "$NO_CHRLIST" ]; then

    # First merge the snp
    PATTERN="$OUTDR/Varscan.snp.*.vcf.gz"
    if stat -t $PATTERN >/dev/null 2>&1; then
        IN=`ls $PATTERN`
        CMD="$BCFTOOLS concat -o $OUT_SNP $IN"
        run_cmd "$CMD" $DRYRUN
        >&2 echo Final SNP output : $OUT_SNP
    else
        >&2 echo $SCRIPT : snp merge: no output found matching $PATTERN
    fi

    # then merge the indel
    PATTERN="$OUTDR/Varscan.indel.*.vcf.gz"
    if stat -t $PATTERN >/dev/null 2>&1; then
        IN=`ls $PATTERN`
        CMD="$BCFTOOLS concat -o $OUT_INDEL $IN"
        run_cmd "$CMD" $DRYRUN
        >&2 echo Final INDEL output : $OUT_INDEL
    else
        >&2 echo $SCRIPT : indel merge: no output found matching $PATTERN
    fi
fi

# compress and index output files
if [ $DO_INDEX ]; then
    >&2 echo Compressing and indexing $OUT_SNP and $OUT_INDEL
    CMD="$BGZIP $OUT_SNP && $BCFTOOLS index $OUT_SNP.gz"
    run_cmd "$CMD" $DRYRUN
    CMD="$BGZIP $OUT_INDEL && $BCFTOOLS index $OUT_INDEL.gz"
    run_cmd "$CMD" $DRYRUN
    OUT_SNP="$OUT_SNP.gz"
    OUT_INDEL="$OUT_INDEL.gz"
fi

if [[ "$FINALIZE" ]] ; then

    LOGD="$OUTD/logs"
    TAR="$OUTD/logs.tar.gz"
    if [ -e $TAR ]; then
        >&2 echo WARNING: $TAR exists
        >&2 echo Skipping log finalize
    else
        CMD="tar -zcf $TAR $LOGD && rm -rf $LOGD"
        run_cmd "$CMD" $DRYRUN
        >&2 echo Logs in $LOGD is compressed as $TAR and deleted
    fi

    if [[ ! "$NO_CHRLIST" ]]; then
        TAR="$OUTD/regions.tar.gz"
        if [ -e $TAR ]; then
            >&2 echo WARNING: $TAR exists
            >&2 echo Skipping regions finalize
        else
            CMD="tar -zcf $TAR $OUTDR && rm -rf $OUTDR"
            run_cmd "$CMD" $DRYRUN
            >&2 echo Intermediate output in $OUTDR is compressed as $TAR and deleted
        fi
    fi
fi


NOW=$(date)
>&2 echo [ $NOW ] $SCRIPT : SUCCESS
