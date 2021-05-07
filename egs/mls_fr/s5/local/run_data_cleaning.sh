#!/usr/bin/env bash


# This script shows how you can do data-cleaning, and exclude data that has a
# higher likelihood of being wrongly transcribed. This didn't help with the 
# LibriSpeech data set, so perhaps the data is already clean enough.
# For the actual results see the comments at the bottom of this script.

stage=1
. ./cmd.sh || exit 1;


. utils/parse_options.sh || exit 1;

set -e


if [ $stage -le 1 ]; then
  steps/cleanup/find_bad_utts.sh \
    --nj 100 \
    --cmd "$train_cmd" \
    data/train \
    data/lang \
    exp/tri5b \
    exp/tri5b_cleanup
fi

thresh=0.1
if [ $stage -le 2 ]; then
  cat exp/tri5b_cleanup/all_info.txt | awk -v threshold=$thresh '{ errs=$2;ref=$3; if (errs <= threshold*ref) { print $1; } }' > uttlist
  utils/subset_data_dir.sh --utt-list uttlist data/train data/train_thresh$thresh
fi

if [ $stage -le 3 ]; then
    steps/align_fmllr.sh \
    --nj 30 \
    --cmd "$train_cmd" \
    data/train.thresh$thresh \
    data/lang \
    exp/tri5b \
    exp/tri5b_ali_$thresh
fi

if [ $stage -le 4 ]; then
    steps/train_sat.sh  \
    --cmd "$train_cmd" \
    7000 150000 \
    data/train_thresh$thresh \
    data/lang \
    exp/tri5b_ali_$thresh  \
    exp/tri5b_$thresh || exit 1;
fi

if [ $stage -le 5 ]; then
    utils/mkgraph.sh \
    data/lang_test \
    exp/tri5b_$thresh \
    exp/tri5b_$thresh/graph || exit 1
  for test in dev; do
    steps/decode_fmllr.sh \
      --nj 50 \
      --cmd "$decode_cmd" \
      --config conf/decode.config \
      exp/tri5b_$thresh/graph \
      data/$test \
      exp/tri5b_$thresh/decode_$test || exit 1
  done
fi
