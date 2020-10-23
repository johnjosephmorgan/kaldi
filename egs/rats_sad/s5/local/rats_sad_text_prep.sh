#!/usr/bin/env bash

# Copyright 2020 ARL (Author: John Morgan)

if [ $# -ne 2 ]; then
  echo "Usage: $0 <rats_sad_dir> <output_dir>"
  echo "<rats_sad_dir> Source Rats corpus location
  echo " <output-dir>: output location
  echo "For example:"
  echo "$0 john@$GPUTHREE:/mnt/corpora/LDC2015S02/RATS_SAD/data data/local/downloads"
  exit 1;
fi

set -eux
src_dir=$1
out_dir=$2

mkdir -p $out_dir

echo "$0: Copying annotations."
for fld dev-1 dev-2 train; do
    cp ${src_dir}/$fld/sad $out_dir
done

exit
annotver=ami_public_manual_1.6.1
annot="$dir/$annotver"

logdir=data/local/downloads; mkdir -p $logdir/log
[ ! -f $annot.zip ] && wget -nv -O $annot.zip $amiurl/AMICorpusAnnotations/$annotver.zip &> $logdir/log/download_ami_annot.log

if [ ! -d $dir/annotations ]; then
  mkdir -p $dir/annotations
  unzip -o -d $dir/annotations $annot.zip &> /dev/null
fi

[ ! -f "$dir/annotations/AMI-metadata.xml" ] && echo "$0: File AMI-Metadata.xml not found under $dir/annotations." && exit 1;


# extract text from AMI XML annotations,
local/ami_xml2text.sh $dir

wdir=data/local/annotations
[ ! -f $wdir/transcripts1 ] && echo "$0: File $wdir/transcripts1 not found." && exit 1;

echo "Preprocessing transcripts..."
local/ami_split_segments.pl $wdir/transcripts1 $wdir/transcripts2 &> $wdir/log/split_segments.log

# make final train/dev/eval splits
for dset in train eval dev; do
  grep -f local/split_$dset.orig $wdir/transcripts2 > $wdir/$dset.txt
done


