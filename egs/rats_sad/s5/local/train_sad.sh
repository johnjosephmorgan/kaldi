#!/usr/bin/env bash

# Copyright  2020  Desh Raj (Johns Hopkins University)
# Copyright  2020  John Morgan (ARL)
# Apache 2.0

# This script trains a Speech Activity detector. It is based on the Aspire
# speech activity detection system. We train with 2 targets:
# speech and silence . 

affix=1a
nnet_type=stat
train_stage=-10
stage=0
nstage=0
nj=50
test_nj=10
targets_dir=data/train_whole
test_sets="dev eval"

. ./cmd.sh

if [ -f ./path.sh ]; then . ./path.sh; fi

set -e -u -o pipefail
. utils/parse_options.sh 

if [ $# != 0 ]; then
  exit
fi

train_set=train
dir=exp/sad_${affix}

train_data_dir=data/${train_set}
whole_data_dir=data/${train_set}_whole
whole_data_id=$(basename $train_set)

mfccdir=mfcc

mkdir -p $dir

ref_rttm=$train_data_dir/rttm.annotation

if [ $stage -le 0 ]; then
  echo "$0 Stage 0: Prepare a whole training data (not segmented) for training the SAD."
  utils/data/convert_data_dir_to_whole.sh $train_data_dir $whole_data_dir
  steps/overlap/get_overlap_segments.py $ref_rttm > $whole_data_dir/sad.rttm
fi

if [ $stage -le 1 ]; then
  echo "$0 Stage 1: Extract features for the whole data directory."
  steps/make_mfcc.sh --nj $nj --cmd "$train_cmd"  --write-utt2num-frames true \
    --mfcc-config conf/mfcc_hires.conf ${whole_data_dir}
  steps/compute_cmvn_stats.sh ${whole_data_dir}
  utils/fix_data_dir.sh ${whole_data_dir}
fi

if [ $stage -le 2 ]; then
  echo "$0 Stage 2: Prepare targets for training the Speech Activity  detector."
  steps/segmentation/prepare_targets_gmm.sh \
    ${whole_data_dir}/utt2num_frames ${whole_data_dir}/rttm.annotation - |\
    copy-feats ark,t:- ark,scp:$dir/targets.ark,$dir/targets.scp
fi

if [ $stage -le 3 ]; then
  if [ $nnet_type == "stat" ]; then
    echo "$0 Stage 3: Train a STATS-pooling network for SAD."
    local/segmentation/tuning/train_stats_sad_1a.sh \
      --stage $nstage --train-stage $train_stage \
      --targets-dir ${targets_dir} \
      --data-dir ${whole_data_dir} --affix "1a" || exit 1
  elif [ $nnet_type == "lstm" ]; then
    # Train a TDNN+LSTM network for SAD
    local/segmentation/tuning/train_lstm_sad_1a.sh \
      --stage $nstage --train-stage $train_stage \
      --targets-dir ${targets_dir} \
      --data-dir ${whole_data_dir}_hires --affix "1a" || exit 1
  fi
fi

exit 0;
