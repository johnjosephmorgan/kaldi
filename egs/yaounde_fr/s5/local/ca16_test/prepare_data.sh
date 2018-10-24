#!/bin/bash

# Copyright 2018 John Morgan
# Apache 2.0.

# ca16 test prep

if [ $# != 1 ]; then
  echo "usage: $0 <CORPUS_DIRECTORY>
example:
$0 African_AccentedFrench";
  exit 1
fi

datadir=$1
tmpdir=data/local/tmp/ca16_test

mkdir -p $tmpdir
#get a list of the ca16 test .wav files
find $datadir -type f -name "*.wav" > $tmpdir/wav_list.txt
#  make ca16 test lists
local/ca16_test/make_lists.pl $datadir
utils/utt2spk_to_spk2utt.pl $tmpdir/lists/utt2spk > $tmpdir/lists/spk2utt
mkdir -p data/test
for x in spk2utt text utt2spk wav.scp; do
  cp $tmpdir/lists/$x data/test/
done
