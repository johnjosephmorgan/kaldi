#!/usr/bin/env bash
# Copyright   2020   ARL (Author: John Morgan)
# Apache 2.0.

# This recipe builds an overlap Detection system.
# It trains on artificially generated data from the MFLTS MSA corpus.

. ./cmd.sh
. ./path.sh
set -euo pipefail
stage=0
nstage=0
train_stage=0
overlap_stage=0
# Path where training data is stored
data_dir=corpus
nj=10
decode_nj=8
test_sets="dev test"
affix=1a
dir=exp/ovl_${affix}

. utils/parse_options.sh

declare -a place;
if [ $stage -le 0 ]; then
  for f in dev test train; do
    # remove previous wav.scp
    [ -f data/$f/wav.scp ] && rm data/$f/wav.scp;
    mkdir -p data/$f
    local/make_wav.scp.pl $f
  done
fi

if [ $stage -le 2 ]; then
  for fld in train $test_sets ; do
    echo "$0 Stage 2: Convert $fld rttm files to utt2spk and segments."
    local/convert_rttm_to_utt2spk_and_segments.py \
      --use-reco-id-as-spkr=false \
      data/$fld/overlap.rttm \
      <(awk '{print $2" "$2" "$3}' data/$fld/overlap.rttm |sort -u) \
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
  echo "$0 Stage 4: Prepare a 'whole' training data (not segmented) directory."
  utils/copy_data_dir.sh data/train data/train_ovl
  cp data/train/overlap.rttm data/train_ovl
  utils/data/convert_data_dir_to_whole.sh data/train_ovl data/train_ovl_whole
  echo "$0: Modify the rttm file."
  steps/overlap/get_overlap_segments.py \
      data/train_ovl/overlap.rttm \
      > data/train_ovl_whole/overlap.rttm
fi

if [ $stage -le 5 ]; then
  echo "$0 Stage 5: Extract features for the 'whole' data directory."
  steps/make_mfcc.sh --nj $nj --cmd "$train_cmd"  --write-utt2num-frames true \
    --mfcc-config conf/mfcc_hires.conf data/train_ovl_whole
  steps/compute_cmvn_stats.sh data/train_ovl_whole
  utils/fix_data_dir.sh data/train_ovl_whole
fi

if [ $stage -le 6 ]; then
  echo "$0 Stage 6: Get targets."
  mkdir -p $dir
  steps/overlap/get_overlap_targets.py \
    data/train_ovl_whole/utt2num_frames \
    data/train_ovl_whole/overlap.rttm - |\
    copy-feats ark:- ark,scp:$dir/targets.ark,$dir/targets.scp
fi

if [ $stage -le 7 ]; then
  echo "$0 Stage 7: Train a TDNN+LSTM network."
  local/segmentation/run_lstm.sh || exit 1
fi

if [ $stage -le 8 ]; then
  for fld in $test_sets; do
    echo "$0 Stage 8: Run overlap detection."
    local/detect_overlaps.sh \
      --convert_data_dir_to_whole true \
      --output-scale "1 2 1" \
      data/${fld} \
      $dir/tdnn_lstm_ovl_${affix} \
      $dir/${fld}
  done
fi

if [ $stage -le 9 ]; then
  for fld in $test_sets; do
    echo "$0 Stage 9: evaluating on $fld output."
    steps/overlap/get_overlap_segments.py \
      data/$fld/overlap.rttm | \
    md-eval.pl -o -c 0.25 -r - -s $dir/$fld/rttm_overlap >\
      $dir/$fld/results.txt
  done
fi