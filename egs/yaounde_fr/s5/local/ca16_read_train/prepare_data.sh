#!/bin/bash

# Copyright 2018 John Morgan
# Apache 2.0.

# ca16 read train prep
yaounde_datadir=$1
datadir=$yaounde_datadir/speech/train/ca16
tmpdir=data/local/tmp/ca16read_train
mkdir -p $tmpdir

#get a list of the ca16 read train .wav files
find $datadir -type f -name "*.wav" | grep read > $tmpdir/wav_list.txt

#  make ca16 read train lists
local/ca16_read_train/make_lists.pl $yaounde_datadir

utils/fix_data_dir.sh $tmpdir/lists
