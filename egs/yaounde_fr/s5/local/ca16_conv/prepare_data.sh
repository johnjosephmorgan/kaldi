#!/bin/bash

# Copyright 2018 John Morgan
# Apache 2.0.

yaounde_datadir=$1
datadir=$yaounde_datadir/speech/train/ca16

tmpdir=data/local/tmp/ca16conv
mkdir -p $tmpdir

find $datadir -type f -name "*.wav" | grep  conv > $tmpdir/wav_list.txt

local/ca16_conv/make_lists.pl $yaounde_datadir

utils/utt2spk_to_spk2utt.pl $tmpdir/lists/

utils/fix_data_dir.sh $tmpdir/lists
