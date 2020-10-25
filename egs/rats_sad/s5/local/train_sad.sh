#!/usr/bin/env bash

# Copyright  2020  Desh Raj (Johns Hopkins University)
# Copyright  2020  John Morgan (ARL)
# Apache 2.0

# This script trains a Speech Activity detector. It is based on the Aspire
# speech activity detection system. We train with 2 targets:
# speech and silence . 

affix=1a

train_stage=-10
stage=0
nj=50
test_nj=10

test_sets="dev eval"

. ./cmd.sh

if [ -f ./path.sh ]; then . ./path.sh; fi

set -e -u -o pipefail
. utils/parse_options.sh 

if [ $# != 1 ]; then
  echo "Usage: $0 <RATS_SAD-corpus-dir>"
  echo "e.g.: $0 /mnt/corpora/LDC2015S02/RATS_SAD"
  echo "Options: "
  echo "  --nj <nj>                                        # number of parallel jobs."
  echo "  --cmd (utils/run.pl|utils/queue.pl <queue opts>) # how to run jobs."
  exit 1;
fi

rats_sad_dir=$1

train_set=train
dir=exp/sad_${affix}

train_data_dir=data/${train_set}
whole_data_dir=data/${train_set}_whole
whole_data_id=$(basename $train_set)

mfccdir=mfcc

mkdir -p $dir

ref_rttm=$train_data_dir/rttm.annotation

if [ $stage -le 0 ]; then
  utils/copy_data_dir.sh data/train $train_data_dir
  cp data/train/rttm.annotation $ref_rttm 
fi

if [ $stage -le 1 ]; then
  # The training data  is already segmented, so we first prepare
  # a "whole" training data (not segmented) for training the SAD
  # detector.
  utils/data/convert_data_dir_to_whole.sh $train_data_dir $whole_data_dir
fi

if [ $stage -le 2 ]; then
  echo "$0 Stage 2: Extract features for the whole data directory."
  steps/make_mfcc.sh --nj $nj --cmd "$train_cmd"  --write-utt2num-frames true \
    --mfcc-config conf/mfcc_hires.conf ${whole_data_dir}
  steps/compute_cmvn_stats.sh ${whole_data_dir}
  utils/fix_data_dir.sh ${whole_data_dir}
fi

if [ $stage -le 3 ]; theneco
  echo "$0 Stage 3: Prepare targets for training the Speech Activity  detector.
  steps/segmentation/prepare_targets_gmm.py \
    ${whole_data_dir}/utt2num_frames ${whole_data_dir}/overlap.rttm - |\
    copy-feats ark,t:- ark,scp:$dir/targets.ark,$dir/targets.scp
fi

if [ $stage -le 4 ]; then
  if [ $nnet_type == "stats" ]; then
  # Train a STATS-pooling network for SAD
  local/segmentation/tuning/train_stats_sad_1a.sh \
    --stage $nstage --train-stage $train_stage \
      --targets-dir ${targets_dir} \
      --data-dir ${whole_data_dir}_hires --affix "1a" || exit 1
  elif [ $nnet_type == "lstm" ]; then
    # Train a TDNN+LSTM network for SAD
    local/segmentation/tuning/train_lstm_sad_1a.sh \
      --stage $nstage --train-stage $train_stage \
      --targets-dir ${targets_dir} \
      --data-dir ${whole_data_dir}_hires --affix "1a" || exit 1
  fi
fi

exit 0;
