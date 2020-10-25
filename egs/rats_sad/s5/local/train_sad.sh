#!/usr/bin/env bash

# Copyright  2017  Nagendra Kumar Goel
#            2017  Vimal Manohar
#            2019  Desh Raj
#            2020  John Morgan
# Apache 2.0

# This script is based on local/run_asr_segmentation.sh script in the
# Aspire recipe. It demonstrates nnet3-based speech activity detection for
# segmentation.
# This script:
# 2. Trains TDNN+Stats or TDNN+LSTM neural network using provided annotations
# 3. Demonstrates using the SAD system to get segments of dev data

lang=data/lang   # Must match the one used to train the models
lang_test=data/lang_test  # Lang directory for decoding.

data_dir=
test_sets=
nstage=-10
train_stage=-10
stage=0
nj=50
reco_nj=40

# test options
test_nj=10

. ./cmd.sh
. ./conf/sad.conf

if [ -f ./path.sh ]; then . ./path.sh; fi

set -e -u -o pipefail
. utils/parse_options.sh 

if [ $# -ne 0 ]; then
  exit 1
fi

dir=exp/segmentation${affix}
sad_work_dir=exp/sad${affix}_${nnet_type}/
sad_nnet_dir=$dir/tdnn_${nnet_type}_sad_1a

mkdir -p $dir
mkdir -p ${sad_work_dir}

#prepare a whole training data (not segmented) for training the SAD system.

whole_data_dir=${data_dir}_whole
whole_data_id=$(basename $whole_data_dir)

if [ $stage -le 0 ]; then
  utils/data/convert_data_dir_to_whole.sh $data_dir $whole_data_dir
fi

###############################################################################
# Extract features for the whole data directory. We extract 13-dim MFCCs to
# generate targets using the GMM system, and 40-dim MFCCs to train the NN-based
# SAD.
###############################################################################
if [ $stage -le 1 ]; then
  steps/make_mfcc.sh --nj $reco_nj --cmd "$train_cmd"  --write-utt2num-frames true \
    --mfcc-config conf/mfcc.conf \
    $whole_data_dir exp/make_mfcc/${whole_data_id}
  steps/compute_cmvn_stats.sh $whole_data_dir exp/make_mfcc/${whole_data_id}
  utils/fix_data_dir.sh $whole_data_dir

  utils/copy_data_dir.sh $whole_data_dir ${whole_data_dir}_hires
  steps/make_mfcc.sh --nj $reco_nj --cmd "$train_cmd"  --write-utt2num-frames true \
    --mfcc-config conf/mfcc_hires.conf \
    ${whole_data_dir}_hires exp/make_mfcc/${whole_data_id}_hires
  steps/compute_cmvn_stats.sh ${whole_data_dir}_hires exp/make_mfcc/${whole_data_id}_hires
  utils/fix_data_dir.sh ${whole_data_dir}_hires
fi

###############################################################################
# Train a neural network for SAD
###############################################################################
if [ $stage -le 2 ]; then
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
