#!/bin/bash

# Copyright 2018 John Morgan
# Apache 2.0.

# yaounde  prep

if [ $# != 1 ]; then
  echo "usage: $0 <CORPUS_DIRECTORY>
example:
$0 African_AccentedFrench";
  exit 1
fi

# set variables
datadir=$1
speech_datadir=$datadir/speech/train/yaounde
tmpdir=data/local/tmp/yaounde
# done setting variables

mkdir -p $tmpdir
#get a list of the yaounde .wav files
find $speech_datadir -type f -name "*.wav" > $tmpdir/wav_list.txt
#  make yaounde lists
local/yaounde/make_lists.pl $datadir
utils/fix_data_dir.sh $tmpdir/lists
