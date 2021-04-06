## VCF Uncompressed sample names

The script repackages a VCF so that the sample names in the VCF header are contained in 0-compressed bgzip blocks. Other contents of the file are compressed with default bgzip compression. DNA nexus requires submitted VCF files to be formatted in this way, as it allows changing sample names without recompressing the entire VCF. The byte range of the 0-compressed blocks is stored such that these blocks can be replaced with other sample names of the same lengths (7). If the third argument is specified and is equal to REMOVE_INPUT then the input data (VCF and index) will be removed after the uncompressed md5sums have been verified. Use REMOVE_INPUT with care!

The uncompressed output VCF is expected to be identical to the uncompressed input. So "zcat input.vcf.gz | md5sum" should be the same as "zcat output.vcf.gz | md5sum" (compressed md5sums won't be the same).

Requires bgzip, tabix, zcat, and several tools from GNU coreutils.

Outputs ${output_prefix}.vcf.gz, ${output_prefix}.vcf.gz.tbi and sample byte coordinates (lo,hi) to ${output_prefix}.samples_byte_range


### Usage

```sh
./vcf_uncompressed_sample_names.sh input.vcf.gz output_prefix [REMOVE_INPUT]
```

### Example

```
mkdir -p test/chr3
./vcf_uncompressed_sample_names.sh /nfs/ukbio/jvc150k/graphtyper/regenotyping/results/chr3/012600001-012650000.vcf.gz test/chr3/012600001-012650000
```

## Support
Hannes P. Eggertsson (hannese@decode.is)
