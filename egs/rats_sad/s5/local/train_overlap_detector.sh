#!/usr/bin/env bash

# Copyright  2020  Desh Raj (Johns Hopkins University)
# Copyright  2020  John Morgan (ARL)
# Apache 2.0

# This script trains an overlap detector.
# It is based on the Aspire speech activity detection system.


affix=1a
dir=exp/ovl_${affix}
nj=10
nnet_type=lstm
nstage=0
stage=0
targets_dir=exp/sad_${affix}
test_nj=10
test_sets=
train_stage=-10


. ./cmd.sh

if [ -f ./path.sh ]; then . ./path.sh; fi

set -e -u -o pipefail
. utils/parse_options.sh 

if [ $# != 0 ]; then
  exit
fi

mkdir -p $dir

if [ $stage -le 4 ]; then
  if [ $nnet_type == "stat" ]; then
    echo "$0 Stage 5<: Train a STATS-pooling network for SAD."
    local/segmentation/tuning/train_stats_sad_1a.sh \
      --stage $nstage --train-stage $train_stage \
      --targets-dir ${targets_dir} \
      --data-dir data/train_sad_whole --affix $affix || exit 1
  elif [ $nnet_type == "lstm" ]; then
    
exit 0;
