#!/usr/bin/env bash

# Copyright  2020  Desh Raj (Johns Hopkins University)
# Copyright  2020  John Morgan (ARL)
# Apache 2.0

# This script trains a Speech Activity detector.
# It is based on the Aspire speech activity detection system.
# It also derives from the ami/s5c overlap recipe.

affix=1a
dir=exp/sad_${affix}
nj=10
nstage=0
stage=0
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
  mkdir -p $dir
  local/get_speech_targets.py \
    data/train_sad_whole/utt2num_frames \
    data/train_sad/rttm.annotation - |\
    copy-feats ark:- ark,scp:$dir/targets.ark,$dir/targets.scp
fi

if [ $stage -le 1 ]; then
  echo "$0 Stage 1: Train a TDNN+LSTM network for SAD."
  local/segmentation/run_lstm.sh \
    --stage $nstage --train-stage $train_stage \
    --targets-dir $dir \
    --data-dir data/train_sad_whole --affix $affix || exit 1
fi

exit 0;
