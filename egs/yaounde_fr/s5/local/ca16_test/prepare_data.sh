#!/bin/bash

# Copyright 2018 John Morgan
# Apache 2.0.

# ca16 test prep
datadir=$1
tmpdir=data/local/tmp/ca16_test
mkdir -p $tmpdir

#get a list of the ca16 test .wav files
find $datadir -type f -name "*.wav" > $tmpdir/wav_list.txt

#  make ca16 test lists
local/ca16_test/make_lists.pl $datadir

utils/fix_data_dir.sh $tmpdir/lists

mkdir -p data/test

for x in spk2utt text utt2spk wav.scp; do
  cp $tmpdir/lists/$x data/test/
done
