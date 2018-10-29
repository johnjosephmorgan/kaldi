#!/bin/bash

# Copyright 2018 John Morgan
# Apache 2.0.

if [ $# != 1 ]; then
  echo "usage: $0 <CORPUS_DIRECTORY>
example:
$0 African_AccentedFrench";
  exit 1
fi

datadir=$1

if [ ! -d $datadir ]; then
  echo "$0: Missing directory $datadir"
fi

local/ca16_conv/prepare_data.sh $datadir
local/ca16_read_devtest/prepare_data.sh $datadir
local/ca16_read_train/prepare_data.sh $datadir
local/ca16_test/prepare_data.sh $datadir
local/niger_dev/prepare_data.sh $datadir
local/yaounde_answers/prepare_data.sh $datadir
local/yaounde_read/prepare_data.sh $datadir

echo "$0: Consolidating training data lists"
mkdir -p data/train
for c in  ca16conv_train ca16read_train yaounde_answers yaounde_read; do
  for x in wav.scp text utt2spk; do
    cat data/local/tmp/$c/lists/$x | tr "	" " " >> data/train/$x
  done
done
utils/utt2spk_to_spk2utt.pl data/train/utt2spk > data/train/spk2utt
utils/fix_data_dir.sh data/train
