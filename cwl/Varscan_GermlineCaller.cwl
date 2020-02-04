class: CommandLineTool
cwlVersion: v1.0
id: Varscan_GermlineCaller
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
    label: Input BAM/CRAM
    secondaryFiles: ${if (self.nameext === ".bam") {return self.basename + ".bai"} else {return self.basename + ".crai"}}
  - id: chrlist
    type: File?
    inputBinding:
      position: 0
      prefix: '-c'
    label: List of genomic regions
  - id: njobs
    type: int?
    inputBinding:
      position: 0
      prefix: '-j'
    label: Parallel job count
    doc: 'Number of jobs to run in parallel mode'
  - id: dryrun
    type: boolean?
    inputBinding:
      position: 0
      prefix: '-d'
    label: dry run
    doc: 'Print out commands but do not execute, for testing only'
  - id: index_output
    type: boolean?
    inputBinding:
      position: 0
      prefix: '-I'
    label: Index output
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
    label: samtools mpileup arguments
  - id: JAVA_ARGS
    type: string?
    inputBinding:
      position: 0
      prefix: '-D'
    label: java arguments
  - id: VS_ARGS
    type: string?
    inputBinding:
      position: 0
      prefix: '-E'
    label: Varscan mpileup2indel and mpileup2snp arguments
outputs:
  - id: snp_vcf
    type: File?
    outputBinding:
      glob: ${if (inputs.index_output ) {return "output/Varscan.snp.Final.vcf.gz" } else {return "output/Varscan.snp.Final.vcf"}}
  - id: indel_vcf
    type: File?
    outputBinding:
      glob: ${if (inputs.index_output ) {return "output/Varscan.indel.Final.vcf.gz" } else {return "output/Varscan.indel.Final.vcf"}}
label: Varscan_GermlineCaller
requirements:
  - class: ResourceRequirement
    ramMin: 8000
  - class: DockerRequirement
    dockerPull: mwyczalkowski/varscan_germlinecaller
  - class: InlineJavascriptRequirement
