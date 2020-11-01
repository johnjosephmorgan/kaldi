#!/usr/bin/env bash

# Copyright  2020  Desh Raj (Johns Hopkins University)
# Copyright  2020  John Morgan (ARL)
# Apache 2.0

# This script trains a Speech Activity detector.
# It is based on the Aspire speech activity detection system.


affix=1a
dir=exp/sad_${affix}
mfccdir=mfcc
nj=20
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

if [ $stage -le 0 ]; then
  echo "$0 Stage 0: Extract features for train data directory."
  local/make_mfcc.sh --nj $nj --cmd "$train_cmd"  --write-utt2num-frames true \
    --mfcc-config conf/mfcc_hires.conf data/train
  steps/compute_cmvn_stats.sh data/train
  utils/fix_data_dir.sh data/train
fi

if [ $stage -le 1 ]; then
  echo "$0 Stage 1: Prepare a 'whole' training data (not segmented) for training the SAD."
  utils/copy_data_dir.sh data/train data/train_sad
  cp data/train/rttm.annotation data/train_sad
  utils/data/convert_data_dir_to_whole.sh data/train_sad data/train_sad_whole
  steps/overlap/get_overlap_segments.py data/train_sad/rttm.annotation > data/train_sad_whole/sad.rttm
fi

if [ $stage -le 2 ]; then
  echo "$0 Stage 2: Extract features for the 'whole' data directory."
  steps/make_mfcc.sh --nj $nj --cmd "$train_cmd"  --write-utt2num-frames true \
    --mfcc-config conf/mfcc_hires.conf data/train_sad_whole
  steps/compute_cmvn_stats.sh data/train_sad_whole
  utils/fix_data_dir.sh data/train_sad_whole
fi

if [ $stage -le 3 ]; then
  echo "$0 Stage 3: Get targets."
  steps/overlap/get_overlap_targets.py \
    data/train_sad_whole/utt2num_frames \
    data/train_sad_whole/sad.rttm - |\
    copy-feats ark,t:- arkt,scp:$dir/targets.txt,$dir/targets.scp
fi

if [ $stage -le 4 ]; then
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
