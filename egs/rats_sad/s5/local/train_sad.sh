#!/usr/bin/env bash

# Copyright  2020  Desh Raj (Johns Hopkins University)
# Copyright  2020  John Morgan (ARL)
# Apache 2.0

# This script trains a Speech Activity detector. It is based on the Aspire
# speech activity detection system.
# Training is done with 4 targets.


affix=1a
dir=exp/sad_${affix}
mfccdir=mfcc
nj=50
nnet_type=lstm
nstage=0
ref_rttm=data/train/rttm.annotation
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

if [ $stage -le 0 ]; then
  echo "$0 Stage 0: Prepare a 'whole' training data (not segmented) for training the SAD."
  utils/data/convert_data_dir_to_whole.sh data/train data/train_hole
fi

if [ $stage -le 1 ]; then
  echo "$0 Stage 1: Get targets."
  local/segmentation/get_sad_targets.py \
    data/train_whole/utt2num_frames \
    data/train_whole/sad.rttm $dir/targets.ark
fi

if [ $stage -le 2 ]; then
  echo "$0 Stage 2: Extract features for the 'whole' data directory."
  steps/make_mfcc.sh --nj $nj --cmd "$train_cmd"  --write-utt2num-frames true \
    --mfcc-config conf/mfcc_hires.conf data/train_whole
  steps/compute_cmvn_stats.sh data/train_whole
  utils/fix_data_dir.sh data/train_whole
fi

if [ $stage -le 3 ]; then
  echo "$0 Stage 3: Prepare targets for training the Speech Activity  detector."
  local/segmentation/get_sad_targets.py \
    data/train_whole/utt2num_frames data/train_whole/sad.rttm - |\
    copy-feats ark,t:- ark,scp:$dir/targets.ark,$dir/targets.scp
fi

if [ $stage -le 4 ]; then
  if [ $nnet_type == "stat" ]; then
    echo "$0 Stage 4<: Train a STATS-pooling network for SAD."
    local/segmentation/tuning/train_stats_sad_1a.sh \
      --stage $nstage --train-stage $train_stage \
      --targets-dir ${targets_dir} \
      --data-dir data/train_whole --affix $affix || exit 1
  elif [ $nnet_type == "lstm" ]; then
    echo "$0 Stage 4: Train a TDNN+LSTM network for SAD."
    local/segmentation/tuning/train_lstm_sad_1a.sh \
      --stage $nstage --train-stage $train_stage \
      --targets-dir $targets_dir \
      --data-dir data/train_whole --affix $affix || exit 1
  fi
fi

exit 0;
