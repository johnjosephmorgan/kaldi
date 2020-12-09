#!/usr/bin/env bash

train_txt_dir=/mnt/corpora/mflts/Modern\ Standard\ Arabic/Speech/annotation/MSA\ Transcription\ TRAINING
tmpdir=data/local/tmp
mflts_tmpdir=$tmpdir/mflts
tmp_train_dir=$mflts_tmpdir/train

echo "$0: Getting a list of the   MFLTS MSA training transcript files."
  find "$train_txt_dir" -type f -name "*.tdf" > $tmp_train_dir/tdf_files.txt
