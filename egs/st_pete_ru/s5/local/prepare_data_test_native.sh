#!/bin/bash

# Copyright 2018 John Morgan
# Apache 2.0.

# Test Data prep for native speakers

if [ $# != 1 ]; then
  echo "usage: $0 <CORPUS_DIRECTORY>
example:
$0 russian";
  exit 1
fi

# set variables
datadir=$1/test/native
speech_datadir=$datadir/audio
tmpdir=data/local/tmp/ru/test_native
# done setting variables

mkdir -p $tmpdir
#get a list of the  .wav files
find $speech_datadir -type f -name "*.wav" > $tmpdir/wav_list.txt
#  make  lists
local/make_lists_test_native.pl $datadir
utils/fix_data_dir.sh $tmpdir/lists
