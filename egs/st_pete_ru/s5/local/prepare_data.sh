#!/bin/bash

# Copyright 2018 John Morgan
# Apache 2.0.

. ./utils/parse_options.sh

if [ $# != 1 ]; then
  echo "usage: $0 <CORPUS_DIRECTORY>
example:
$0 russian";
  exit 1
fi

# set variables
datadir=$1
tmpdir=data/local/tmp/ru
# done setting variables 

if [ ! -d $datadir ]; then
  echo "$0: Missing directory $datadir"
fi

local/prepare_data_train.sh $datadir
local/prepare_data_test_native.sh $datadir
local/prepare_data_test_nonnative.sh $datadir

utils/utt2spk_to_spk2utt.pl data/train/utt2spk > data/train/spk2utt
utils/fix_data_dir.sh data/train

echo "$0: Consolidating test data lists"
mkdir -p data/test
for c in  test_native test_nonnative; do
  for x in wav.scp text utt2spk; do
    cat $tmpdir/$c/lists/$x | tr "	" " " >> data/test/$x
  done
done
utils/utt2spk_to_spk2utt.pl data/test/utt2spk > data/test/spk2utt
utils/fix_data_dir.sh data/test
