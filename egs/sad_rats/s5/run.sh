#!/usr/bin/env bash
# Copyright   2020   ARL (Author: John Morgan)
# Apache 2.0.

# This recipe builds a Speech Activity Detection system on the rats_sad corpus.
# The LDC identifyer for the rats_sad corpus is LDC2015S02.
. ./cmd.sh
. ./path.sh
set -euo pipefail
stage=0
sad_stage=0
# Path where RATS_SAD gets downloaded (or where locally available):
rats_sad_data_dir=/mnt/corpora/LDC2015S02/RATS_SAD/data
nj=10
decode_nj=4
train_set=train
test_sets="dev-1 dev-2 "
. utils/parse_options.sh

if [ $stage -le 0 ]; then
  echo "$0 Stage 0: Get  all info files."
  local/rats_sad_text_prep.sh $rats_sad_data_dir
fi

if [ $stage -le 1 ]; then
  echo "$0 Stage 1: Preparing data directories."
  for fld in train $test_sets ; do
    echo "$0: preparing $fld set."
    mkdir -p data/$fld
    local/prepare_data.py data/local/annotations/$fld.txt \
      $rats_sad_data_dir/$fld/audio/ data/$fld
  done
fi

if [ $stage -le 2 ]; then
  for fld in train $test_sets ; do
    echo "$0 Stage 2: Convert $fld rttm files to utt2spk."
    local/convert_rttm_to_utt2spk_and_segments.py --use-reco-id-as-spkr=true \
      data/$fld/rttm.annotation \
      <(awk '{print $2" "$2" "$3}' data/$fld/rttm.annotation |sort -u) \
      data/$fld/utt2spk data/$fld/segments

    utils/utt2spk_to_spk2utt.pl data/$fld/utt2spk > data/$fld/spk2utt
    utils/fix_data_dir.sh data/$fld
  done
fi

if [ $stage -le 3 ]; then
  echo "$0 Stage 3: Extract features for train data directory."
  local/make_mfcc.sh --nj $nj --cmd "$train_cmd"  --write-utt2num-frames true \
    --mfcc-config conf/mfcc_hires.conf data/train
  steps/compute_cmvn_stats.sh data/train
  utils/fix_data_dir.sh data/train
fi

if [ $stage -le 4 ]; then
  echo "$0 Stage 4: Prepare a 'whole' training data (not segmented) for training the SAD."
  utils/copy_data_dir.sh data/train data/train_sad
  cp data/train/rttm.annotation data/train_sad
  utils/data/convert_data_dir_to_whole.sh data/train_sad data/train_sad_whole
fi

if [ $stage -le 5 ]; then
  echo "$0 Stage 5: Extract features for the 'whole' data directory."
  steps/make_mfcc.sh --nj $nj --cmd "$train_cmd"  --write-utt2num-frames true \
    --mfcc-config conf/mfcc_hires.conf data/train_sad_whole
  steps/compute_cmvn_stats.sh data/train_sad_whole
  utils/fix_data_dir.sh data/train_sad_whole
fi

if [ $stage -le 6 ]; then
  echo "$0 Stage 6: training a Speech Activity detector."
  local/train_sad.sh --stage $sad_stage --test-sets "$test_sets"
fi

sad_affix=1a
if [ $stage -le 7 ]; then
  for fld in $test_sets; do
    echo "$0 Stage 7: Run SAD detection on $fld."
    local/detect_speech_activity.sh \
      --output-scale "1 2" \
      data/${fld} \
      exp/segmentation_${sad_affix}/tdnn_lstm_asr_sad_${sad_affix} \
      exp/segmentation_${sad_affix}/${fld}_sad
  done
fi

if [ $stage -le 8 ]; then
  for fld in $test_sets; do
    steps/segmentation/convert_utt2spk_and_segments_to_rttm.py \
      data/${fld}_whole/utt2spk \
      exp/segmentation_${sad_affix}/tdnn_lstm_asr_sad_${sad_affix}/segments
    exp/segmentation_${sad_affix}/sad.rttm
  done
fi

if [ $stage -le 9 ]; then
    for fld in $test_sets; do
    echo "$0 Stage 9: evaluating $fld output."
    md-eval.pl -r data/$fld/rttm.annotation \
      -s exp/segmentation_${sad_affix}/tdnn_lstm_asr_sad_${fld}/rttm_sad |\
      awk 'or(/MISSED SPEAKER TIME/,/FALARM SPEAKER TIME/)'
  done
fi
