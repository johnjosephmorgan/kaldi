#!/bin/bash

# Copyright, University of Edinburgh (Pawel Swietojanski and Jonathan Kilgour)

if [ $# -ne 1 ]; then
  echo "Usage: $0 <ami-dir>"
  exit 1;
fi

adir=$1
wdir=data/local/annotations

[ ! -f $adir/annotations/AMI-metadata.xml ] && echo "$0: File $adir/annotations/AMI-metadata.xml no found." && exit 1;

mkdir -p $wdir/log
echo "$0: Downloading exported version of transcripts."
annots=ami_manual_annotations_v1.6.1_export
wget -O $wdir/$annots.gzip http://groups.inf.ed.ac.uk/ami/AMICorpusAnnotations/$annots.gzip
gunzip -c $wdir/${annots}.gzip > $wdir/transcripts0
exit 0;
