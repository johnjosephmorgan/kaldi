#!/bin/bash
# yaounde  prep

datadir=$1

tmpdir=data/local/tmp/yaounde
mkdir -p $tmpdir

#get a list of the yaounde .wav files
find $datadir -type f -name "*.wav" | grep 16000 > $tmpdir/wav_list.txt

#  make yaounde lists
local/yaounde/make_lists.pl datadir

utils/fix_data_dir.sh $tmpdir/lists
