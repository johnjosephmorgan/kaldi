#!/bin/bash

# Copyright 2018 John Morgan
# Apache 2.0.

# yaounde  prep

yaounde_datadir=$1
datadir=$yaounde_datadir/speech
tmpdir=data/local/tmp/yaounde
mkdir -p $tmpdir

#get a list of the yaounde .wav files
find $datadir -type f -name "*.wav" > $tmpdir/wav_list.txt

#  make yaounde lists
local/yaounde/make_lists.pl $yaounde_datadir

utils/fix_data_dir.sh $tmpdir/lists
