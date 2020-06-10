class: CommandLineTool
cwlVersion: v1.0
id: varscan_germlinecaller
baseCommand:
  - /bin/bash
  - /opt/Varscan_GermlineCaller/src/process_sample_parallel.sh
inputs:
  - id: reference
    type: File
    inputBinding:
      position: 1
    label: Reference FASTA
    secondaryFiles:
      - .fai
  - id: bam
    type: File
    inputBinding:
      position: 2
    label: Input BAM
    secondaryFiles: ${if (self.nameext === ".bam") {return self.basename + ".bai"} else {return self.basename + ".crai"}}
  - id: chrlist
    type: File?
    inputBinding:
      position: 0
      prefix: '-c'
    doc: List of genomic regions
    label: Genomic regions
  - id: njobs
    type: int?
    inputBinding:
      position: 0
      prefix: '-j'
    label: N parallel jobs
    doc: 'Number of jobs to run in parallel mode'
  - id: dryrun
    type: boolean?
    inputBinding:
      position: 0
      prefix: '-d'
    label: dry run
    doc: 'Print out commands but do not execute, for testing only'
  - id: compress_output
    type: boolean?
    inputBinding:
      position: 0
      prefix: '-I'
    label: Compress output
    doc: 'Compress and index output VCF files'
  - id: finalize
    type: boolean?
    inputBinding:
      position: 0
      prefix: '-F'
    label: finalize
    doc: 'Compress intermediate data and logs'
  - id: MP_ARGS
    type: string?
    inputBinding:
      position: 0
      prefix: '-C'
    doc: samtools mpileup arguments
    label: mpileup args
  - id: JAVA_ARGS
    type: string?
    inputBinding:
      position: 0
      prefix: '-D'
    label: JAVA args
  - id: VS_ARGS
    type: string?
    inputBinding:
      position: 0
      prefix: '-E'
    doc: Varscan mpileup2indel and mpileup2snp arguments
    label: mpileup2 args
outputs:
  - id: snp_vcf
    type: File?
    outputBinding:
      glob: ${if (inputs.compress_output ) {return "output/Varscan.snp.Final.vcf.gz" } else {return "output/Varscan.snp.Final.vcf"}}
  - id: indel_vcf
    type: File?
    outputBinding:
      glob: ${if (inputs.compress_output ) {return "output/Varscan.indel.Final.vcf.gz" } else {return "output/Varscan.indel.Final.vcf"}}
label: Varscan_GermlineCaller
requirements:
  - class: ResourceRequirement
    ramMin: 8000
  - class: DockerRequirement
    dockerPull: mwyczalkowski/varscan_germlinecaller:20200608
  - class: InlineJavascriptRequirement
