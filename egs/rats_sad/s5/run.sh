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
rats_sad_dev_2_tab_dir=/mnt/corpora/LDC2015S02/RATS_SAD/data/dev-2/sad
rats_sad_train_tab_dir=/mnt/corpora/LDC2015S02/RATS_SAD/data/train/sad
rats_sad_dev_audio_dir=/mnt/corpora/LDC2015S02/RATS_SAD/data/dev-1/audio
rats_sad_eval_audio_dir=/mnt/corpora/LDC2015S02/RATS_SAD/data/dev-2/audio
rats_sad_train_audio_dir=/mnt/corpora/LDC2015S02/RATS_SAD/data/train/audio

if [ $stage -le 0 ]; then
  echo "$0 Stage 0: Get  all info files."
  mkdir -p data/local/annotations
  find $rats_sad_train_tab_dir -type f -name "*.tab" | xargs cat > data/local/annotations/train.txt
  find $rats_sad_dev_1_tab_dir -type f -name "*.tab" | xargs cat > data/local/annotations/dev.txt
  find $rats_sad_dev_2_tab_dir -type f -name "*.tab" | xargs cat > data/local/annotations/eval.txt
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

    # For the test sets we create dummy segments and utt2spk files using oracle speech marks
    if ! [ $fld == "train" ]; then
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

