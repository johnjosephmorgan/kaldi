#!/bin/bash

# Copyright 2018 John Morgan
# Apache 2.0.

# ca16 read devtest prep
yaounde_datadir=$1
datadir=$yaounde_datadir/speech/devtest/ca16
tmpdir=data/local/tmp/ca16read_devtest
mkdir -p $tmpdir

#get a list of the ca16 read devtest .wav files
find $datadir -type f -name "*.wav" | grep read > $tmpdir/wav_list.txt

#  make ca16 read devtest lists
local/ca16_read_devtest/make_lists.pl $yaounde_datadir

utils/fix_data_dir.sh $tmpdir/lists

mkdir -p data/devtest

for x in spk2utt text utt2spk wav.scp; do
  cp $tmpdir/lists/$x data/devtest/
done
