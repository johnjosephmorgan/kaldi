#!/bin/bash

# Copyright 2018 John Morgan
# Apache 2.0.

# niger dev prep
yaounde_datadir=$1
datadir=$yaounde_datadir/speech/dev/niger_west_african_fr
tmpdir=data/local/tmp/niger
mkdir -p $tmpdir

#get a list of the niger .wav files
find $datadir -type f -name "*.wav" > $tmpdir/wav_list.txt

#  make niger dev lists
local/niger_dev/make_lists.pl $yaounde_datadir

utils/fix_data_dir.sh $tmpdir/lists

mkdir -p data/dev

for x in spk2utt text utt2spk wav.scp; do
  cp $tmpdir/lists/$x data/dev/
done