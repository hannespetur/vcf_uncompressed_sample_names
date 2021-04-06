#!/bin/bash

set -o pipefail

if [[ "$2" == "" ]]
then
  echo "Usage: $0 file.vcf.gz output_prefix [REMOVE_INPUT]"
  echo ""
  echo "  Repackages the VCF so that the samples in the header are contained in 0-compressed bgzip block. \
Other contents of the file are compressed with default compression. If the third argument is specified \
then the input data (VCF and index) will be removed after the uncompressed md5sums have been verified."
  echo ""
  echo "  Requires bgzip, tabix, zcat, and several tools from GNU coreutils."
  echo "  Outputs \${output_prefix}.vcf.gz, \${output_prefix}.vcf.gz.tbi and sample byte coordinates (lo,hi) to\
 \${output_prefix}.samples_byte_range"
  exit 1
fi

BGZIP=/nfs/fs1/bioinfo/apps-x86_64/htslib/1.9/bin/bgzip
TABIX=/nfs/fs1/bioinfo/apps-x86_64/htslib/1.9/bin/tabix

if [[ "$3" == "REMOVE_INPUT" ]]; then
  echo "== WARNING: I will remove the input vcfgz after the md5sums have been verified. =="
  echo "==  Stop the script now if you dont want to do this! You have 5 seconds. =="
  sleep 5
fi

vcfgz_path="$1"
output_prefix="$2"
outfile="${output_prefix}.vcf.gz"
samples_byte_range="${output_prefix}.samples_byte_range"

if [[ ! -s ${vcfgz_path} ]] || [[ ! -s ${vcfgz_path}.tbi ]]; then
  echo "ERROR: No such file or empty: ${vcfgz_path} + ${vcfgz_path}.tbi" >&2
  exit 1
fi

if [[ -e ${outfile} ]] || [[ -e ${outfile}.tbi ]]; then
  echo "ERROR: Output file exists! ${outfile} / ${outfile}.tbi"
  exit 1
fi

if [[ -e ${samples_byte_range} ]]; then
  echo "ERROR: Output file exists! ${samples_byte_range}"
  exit 1
fi

# Get uncompressed header up until the sample names, bgzip with default options
zcat ${vcfgz_path} | awk '$1 ~ /^##/{print} $1 ~ /^#CHROM/{for (i=1; i<=9; i++) { printf("%s\t", $i) }} $1 !~ /^#/{exit 141}' | ${BGZIP} | head -c -28 > ${outfile}

# Mark the starting byte range
lo=`stat -c '%s' ${outfile}`
let lo++

# Reprint sample ids with 7 digits (with leading zeros if needed) and bgzip with 0-compression
zcat ${vcfgz_path} | awk '$1 ~ /^#CHROM/{print} $1 ~ /^chr/{exit 0}' | awk '{for (i=10; i<=NF; i++) {printf "%07d%c", $i, (i==NF?"\n":"\t")}}' | ${BGZIP} -l 0 | head -c -28 >> "$outfile"

# Mark the ending byte range
hi=`stat -c '%s' ${outfile}`

# Bgzip the rest of the file
zcat ${vcfgz_path} | awk '$1 !~ /^#/{print}' | ${BGZIP} -@ `nproc` >> "$outfile"

# Tabix the output file
${TABIX} -p vcf ${outfile}

# Calculate uncompressed md5sum of input and output vcf
if [[ ! -s ${outfile} ]] || [[ ! -s ${outfile}.tbi ]]; then
  echo "ERROR: No output file or file is empty: ${outfile} + ${outfile}.tbi" >&2
  exit 1
fi

# Create temporary files containing the MD5 sums
MD5_old=`mktemp`
MD5_new=`mktemp`

zcat ${vcfgz_path} | md5sum > ${MD5_old} &
zcat ${outfile} | md5sum > ${MD5_new} &

# Wait for both md5sums to be calculated
wait

# Check if md5sums match
if [[ -s ${MD5_old} ]] && [[ -s ${MD5_new} ]] && [[ `diff -q ${MD5_old} ${MD5_new}` == "" ]]
then
  echo "OK! md5sums match. Samples byte range: $lo $hi"

  # Output the byte range of the sample names:
  echo $lo $hi > ${samples_byte_range}

  # Calculate md5sums
  md5sum ${outfile} > ${outfile}.md5
  md5sum ${outfile}.tbi > ${outfile}.tbi.md5
  md5sum ${samples_byte_range} > ${samples_byte_range}.md5

  if [[ ! -s ${outfile} ]] || [[ ! -s ${outfile}.md5 ]] || \
       [[ ! -s ${outfile}.tbi ]] || [[ ! -s ${outfile}.tbi.md5 ]] || \
       [[ ! -s ${samples_byte_range} ]] || [[ ! -s ${samples_byte_range}.md5 ]]
  then
    echo "ERROR: One or more output file missing!"
    exit 1
  fi

  if [[ "$3" == "REMOVE_INPUT" ]]; then
    rm ${vcfgz_path} ${vcfgz_path}.tbi
  else
    echo "rm ${vcfgz_path} ${vcfgz_path}.tbi"
  fi
else
  echo "NOT OK! Input file: ${vcfgz_path}"
  cat ${MD5_old}
  echo " != "
  cat ${MD5_new}
  exit 1
fi

rm -f ${MD5_old} ${MD5_new}
exit 0
