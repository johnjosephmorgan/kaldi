#!/usr/bin/env bash
# Copyright   2020   ARL (Author: John Morgan)
# Apache 2.0.
#
# This recipe performs Speech Activity Detection for the rats_sad corpus.

. ./cmd.sh
. ./path.sh
set -euo pipefail
mfcc_dir=`pwd`/mfcc

stage=0
sad_stage=0

nj=50
decode_nj=15


train_set=train
test_sets="dev-1 dev-2 "

. utils/parse_options.sh

# Path where RATS_SAD gets downloaded (or where locally available):
rats_sad_data_dir=/mnt/corpora/LDC2015S02/RATS_SAD/data
rats_sad_dev_1_tab_dir=/mnt/corpora/LDC2015S02/RATS_SAD/data/dev-1/sad
rats_sad_dev-2_tab_dir=$rats_sad_data_dir/dev-2/sad
rats_sad_train_tab_dir=$rats_sad_data_dir/train/sad

if [ $stage -le 0 ]; then
  echo "$0: Preparing data directories."
  if ! [ -d data/local/annotations ]; then
    local/rats_text_prep.sh $rats_dir data/local/downloads
  fi

  for dataset in train $test_sets; do
    echo "$0: preparing $dataset set.."
    mkdir -p data/$dataset
    local/prepare_data.py data/local/annotations/${dataset}.txt \
      $AMI_DIR data/$dataset
    local/convert_rttm_to_utt2spk_and_segments.py --append-reco-id-to-spkr=true data/$dataset/rttm.annotation \
      <(awk '{print $2" "$2" "$3}' data/$dataset/rttm.annotation |sort -u) \
      data/$dataset/utt2spk data/$dataset/segments

    # For the test sets we create dummy segments and utt2spk files using oracle speech marks
    if ! [ $dataset == "train" ]; then
      local/get_all_segments.py data/$dataset/rttm.annotation > data/$dataset/segments
      awk '{print $1,$2}' data/$dataset/segments > data/$dataset/utt2spk
    fi

    utils/utt2spk_to_spk2utt.pl data/$dataset/utt2spk > data/$dataset/spk2utt
    utils/fix_data_dir.sh data/$dataset
  done
fi

# Feature extraction
if [ $stage -le 3 ]; then
  for dataset in train $test_sets; do
    steps/make_mfcc.sh --mfcc-config conf/mfcc_hires.conf --nj $nj --cmd "$train_cmd" data/$dataset
    steps/compute_cmvn_stats.sh data/$dataset
    utils/fix_data_dir.sh data/$dataset
  done
fi

if [ $stage -le 4 ]; then
  echo "$0: preparing a AMI training data to train PLDA model"
  local/nnet3/xvector/prepare_feats.sh --nj $nj --cmd "$train_cmd" \
    data/train data/plda_train exp/plda_train_cmn
fi

if [ $stage -le 5 ]; then
  echo "$0: extracting x-vector for PLDA training data"
  utils/fix_data_dir.sh data/plda_train
  diarization/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd --mem 10G" \
    --nj $nj --window 3.0 --period 10.0 --min-segment 1.5 --apply-cmn false \
    --hard-min true $model_dir \
    data/plda_train $model_dir/xvectors_plda_train
fi

# Train PLDA models
if [ $stage -le 6 ]; then
  echo "$0: training PLDA model"
  # Compute the mean vector for centering the evaluation xvectors.
  $train_cmd $model_dir/xvectors_plda_train/log/compute_mean.log \
    ivector-mean scp:$model_dir/xvectors_plda_train/xvector.scp \
    $model_dir/xvectors_plda_train/mean.vec || exit 1;

  # Train the PLDA model.
  $train_cmd $model_dir/xvectors_plda_train/log/plda.log \
    ivector-compute-plda ark:$model_dir/xvectors_plda_train/spk2utt \
    "ark:ivector-subtract-global-mean scp:$model_dir/xvectors_plda_train/xvector.scp ark:- |\
     transform-vec $model_dir/xvectors_plda_train/transform.mat ark:- ark:- |\
      ivector-normalize-length ark:-  ark:- |" \
    $model_dir/xvectors_plda_train/plda || exit 1;
  
  cp $model_dir/xvectors_plda_train/plda $model_dir/
  cp $model_dir/xvectors_plda_train/transform.mat $model_dir/
  cp $model_dir/xvectors_plda_train/mean.vec $model_dir/
fi

if [ $stage -le 7 ]; then
  for datadir in ${test_sets}; do
    ref_rttm=data/${datadir}/rttm.annotation

    nj=$( cat data/$datadir/wav.scp | wc -l )
    local/diarize_${diarizer_type}.sh --nj $nj --cmd "$train_cmd" --stage $diarizer_stage \
      $model_dir data/${datadir} exp/${datadir}_diarization_${diarizer_type}

    # Evaluate RTTM using md-eval.pl
    md-eval.pl -r $ref_rttm -s exp/${datadir}_diarization_${diarizer_type}/rttm
  done
fi

# These stages demonstrate how to perform training and inference
# for an overlap detector.
if [ $stage -le 8 ]; then
  echo "$0: training overlap detector"
  local/train_overlap_detector.sh --stage $overlap_stage --test-sets "$test_sets" $rats_dir
fi

overlap_affix=1a
if [ $stage -le 9 ]; then
  for dataset in $test_sets; do
    echo "$0: performing overlap detection on $dataset"
    local/detect_overlaps.sh --convert_data_dir_to_whole true \
      --output-scale "1 2 1" data/${dataset} \
      exp/overlap_$overlap_affix/tdnn_lstm_1a exp/overlap_$overlap_affix/$dataset

    echo "$0: evaluating output.."
    steps/overlap/get_overlap_segments.py data/$dataset/rttm.annotation | grep "overlap" |\
      md-eval.pl -r - -s exp/overlap_$overlap_affix/$dataset/rttm_overlap |\
      awk 'or(/MISSED SPEAKER TIME/,/FALARM SPEAKER TIME/)'
  done
fi

