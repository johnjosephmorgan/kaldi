#!/bin/bash

if [ $# != 7 ]; then
  echo "usage: local/prepare_data.sh <GP_data-dir> <SRICA_DATA_DIR> <GABONREAD_DATA_DIR> <GABON_CONV_DATA_DIR> <NIGER_DATA_DIR> <YAOUNDE_DATA_DIR> <CENTRAL_ACCORD_TEST_DATA_DIR>"
  exit 1
fi

gp_corpus=$1
srica_corpus=$2
gabonread_corpus=$3
gabonconv_corpus=$4
niger_corpus=$5
yaounde_corpus=$6
ca_test_corpus=$7

local/gp/prepare_data.sh $gp_corpus
local/srica/prepare_data.sh $srica_corpus
local/gabon_read/prepare_data.sh $gabonread_corpus
local/gabon_conv/prepare_data.sh $gabonconv_corpus
local/niger/prepare_data.sh $niger_corpus
local/yaounde/prepare_data.sh $yaounde_corpus
local/central_accord/prepare_data.sh $ca_test_corpus

echo "$0: Consolidating training data lists"
mkdir -p data/train
for c in gabonread gp niger yaounde gabonconv; do
  for x in wav.scp text utt2spk; do
    cat data/local/tmp/$c/lists/$x >> data/train/$x
  done
done

utils/utt2spk_to_spk2utt.pl data/train/utt2spk > data/train/spk2utt

utils/fix_data_dir.sh data/train
