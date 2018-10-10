#!/bin/bash

# Copyright 2018 John Morgan
# Apache 2.0.

if [ $# != 1 ]; then
  echo "usage: $0 <YAOUNDE_CORPUS_DIRECTORY>";
  exit 1
fi

yaounde_corpus=$1

local/ca16_conv/prepare_data.sh $yaounde_corpus
local/ca16_read/prepare_data.sh $yaounde_corpus
local/ca16_test/prepare_data.sh $yaounde_corpus
local/niger_dev/prepare_data.sh $yaounde_corpus
local/yaounde/prepare_data.sh $yaounde_corpus

echo "$0: Consolidating training data lists"
mkdir -p data/train
for c in  ca16conv ca16read yaounde; do
  for x in wav.scp text utt2spk; do
    cat data/local/tmp/$c/lists/$x >> data/train/$x
  done
done

utils/utt2spk_to_spk2utt.pl data/train/utt2spk > data/train/spk2utt

utils/fix_data_dir.sh data/train
