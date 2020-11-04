#!/usr/bin/env bash

# Copyright  2020  Desh Raj (Johns Hopkins University)
# Copyright  2020  John Morgan (ARL)
# Apache 2.0

# This script trains a Speech Activity detector.
# It is based on the Aspire speech activity detection system.
# It also derives from the ami/s5c overlap recipe.

affix=1a
dir=exp/sad_${affix}
nj=16
nnet_type=lstm
nstage=0
stage=0
targets_dir=exp/sad_${affix}
test_nj=8
test_sets=
train_stage=-10
dir=exp/sad_${affix}

. ./cmd.sh
if [ -f ./path.sh ]; then . ./path.sh; fi
set -e -u -o pipefail
. utils/parse_options.sh 

if [ $# != 0 ]; then
  exit
fi

if [ $stage -le 0 ]; then
  echo "$0 Stage 0: Get targets."
  local/get_speech_targets.py \
    data/train_sad_whole/utt2num_frames \
    data/train_sad/rttm.annotation - |\
    copy-feats ark:- ark,scp:$dir/targets.ark,$dir/targets.scp
fi

if [ $stage -le 1 ]; then
  if [ $nnet_type == "stat" ]; then
    echo "$0 Stage 5<: Train a STATS-pooling network for SAD."
    local/segmentation/tuning/train_stats_sad_1a.sh \
      --stage $nstage --train-stage $train_stage \
      --targets-dir ${targets_dir} \
      --data-dir data/train_sad_whole --affix $affix || exit 1
  elif [ $nnet_type == "lstm" ]; then
    echo "$0 Stage 5: Train a TDNN+LSTM network for SAD."
    local/segmentation/tuning/train_lstm_sad_1a.sh \
      --stage $nstage --train-stage $train_stage \
      --targets-dir $targets_dir \
      --data-dir data/train_sad_whole --affix $affix || exit 1
  fi
fi

exit 0;
