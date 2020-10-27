#!/usr/bin/env bash
# Copyright   2020   ARL (Author: John Morgan)
# Apache 2.0.
#
# This recipe performs Speech Activity Detection for the rats_sad corpus.

. ./cmd.sh
. ./path.sh
set -euo pipefail

stage=0
sad_stage=0

nj=50
decode_nj=15


train_set=train
test_sets="dev eval "

. utils/parse_options.sh

# Path where RATS_SAD gets downloaded (or where locally available):
rats_sad_data_dir=/mnt/corpora/LDC2015S02/RATS_SAD/data
rats_sad_dev_audio_dir=/mnt/corpora/LDC2015S02/RATS_SAD/data/dev-1/audio
rats_sad_eval_audio_dir=/mnt/corpora/LDC2015S02/RATS_SAD/data/dev-2/audio
rats_sad_train_audio_dir=/mnt/corpora/LDC2015S02/RATS_SAD/data/train/audio

if [ $stage -le 0 ]; then
  echo "$0 Stage 0: Get  all info files."
  local/rats_sad_texxt_prep.sh $rats_sad_data_dir
fi

if [ $stage -le 1 ]; then
  echo "$0 Stage 1: Preparing data directories."
  echo "$0: preparing training set."
  mkdir -p data/train
  local/prepare_data.py data/local/annotations/train.txt \
    $rats_sad_train_audio_dir data/train

  echo "$0: preparing dev set."
  mkdir -p data/dev
  local/prepare_data.py data/local/annotations/dev.txt \
    $rats_sad_dev_audio_dir data/dev

  echo "$0: preparing eval set."
  mkdir -p data/eval
  local/prepare_data.py data/local/annotations/eval.txt \
    $rats_sad_eval_audio_dir data/eval
fi

if [ $stage -le 2 ]; then
  echo "$0 Stage 2: Convert rttm files to utt2spk."
  for fld in train dev eval; do
    local/convert_rttm_to_utt2spk_and_segments.py --append-reco-id-to-spkr=true data/$fld/rttm.annotation \
      <(awk '{print $2" "$2" "$3}' data/$fld/rttm.annotation |sort -u) \
      data/$fld/utt2spk data/$fld/segments

    if ! [ $fld == "train" ]; then
      echo "Create dummy segments and utt2spk files using oracle speech marks for $fld."
      local/get_all_segments.py data/$fld/rttm.annotation > data/$fld/segments
      awk '{print $1,$2}' data/$fld/segments > data/$fld/utt2spk
    fi

    utils/utt2spk_to_spk2utt.pl data/$fld/utt2spk > data/$fld/spk2utt
    utils/fix_data_dir.sh data/$fld
  done
fi

if [ $stage -le 3 ]; then
  echo "$0 Stage 3: training a Speech Activity detector."
  local/train_sad.sh --stage $sad_stage --test-sets "$test_sets"
fi

sad_affix=1a
if [ $stage -le 4 ]; then
    for dataset in $test_sets; do
    echo "$0 Stage 4: Extract features for $dataset."
    steps/make_mfcc.sh --mfcc-config conf/mfcc_hires.conf --nj $nj --cmd "$train_cmd" data/$dataset
    steps/compute_cmvn_stats.sh data/$dataset
    utils/fix_data_dir.sh data/$dataset

    echo "$0 Stage 4: performing Speech Activity detection on $dataset"
    local/segmentation/detect_speech_activity.sh \
      data/$dataset \
      exp/segmentation_${sad_affix}/tdnn_lstm_asr_sad_${sad_affix} \
      mfcc_hires \
      exp/segmentation<_${sad_affix}/tdnn_lstm_asr_sad_${sad_affix} \
      data/$dataset

    echo "$0: evaluating $dataset output."
  steps/overlap/get_overlap_segments.py data/$dataset/rttm.annotation | \
      md-eval.pl -r - -s exp/sad_$sad_affix/$dataset/rttm_sad |\
      awk 'or(/MISSED SPEAKER TIME/,/FALARM SPEAKER TIME/)'
  done
fi
