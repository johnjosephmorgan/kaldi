#!/usr/bin/env bash
. ./cmd.sh
. ./path.sh
stage=0

. ./utils/parse_options.sh

set -e
set -o pipefail
set u

if [ $stage -le 0 ]; then
  echo "$0: Converting buckwalter to utf8 in GALE lexicon."
  local/gale/bw2utf8.sh || exit 1;
  rm -Rf GALE
  echo "$0: Moving the GALE data."
  mkdir -p $gale_tmp_dir/lists
  mv data/{test,train} $gale_tmp_dir/lists
fi

if [ $stage -le 1 ]; then
  echo "$0: extracting acoustic features for GALE."
  for f in train test; do
    utils/fix_data_dir.sh data/local/tmp/gale/lists/$f
    steps/make_mfcc.sh --cmd "$train_cmd" --nj 56 data/local/tmp/gale/lists/$f
    steps/compute_cmvn_stats.sh data/local/tmp/gale/lists/$f 
    utils/fix_data_dir.sh data/local/tmp/gale/lists/$f
  done
  ln -s data/local/tmp/gale/lists/train data/gale/
fi

if [ $stage -le 2 ]; then
  echo "$0: Train monophones on Gale."
  steps/train_mono.sh  --cmd "$train_cmd" --nj 56 data/gale/train \
		       data/lang exp/gale/mono || exit 1;
fi

if [ $stage -le 3 ]; then
  echo "$0: aligning with monophones"
  steps/align_si.sh  --cmd "$train_cmd" --nj 56 data/gale/train data/lang \
		     exp/gale/mono exp/gale/mono_ali || exit 1;
fi

if [ $stage -le 4 ]; then
  echo "$0: Starting  GALE triphone training in exp/gale/tri1."
  steps/train_deltas.sh --cmd "$train_cmd" --boost-silence 1.25 \
    5500 90000 \
    data/gale/train data/lang exp/gale/mono_ali exp/gale/tri1 || exit 1;
fi

if [ $stage -le 5 ]; then
  echo "$0: Aligning with GALE triphones tri1."
  steps/align_si.sh  --cmd "$train_cmd" --nj 56 data/gale/train data/lang \
    exp/gale/tri1 exp/gale/tri1_ali || exit 1;s
fi

if [ $stage -le 6 ]; then
  echo "$0: Starting GALE lda_mllt triphone training in exp/gale/tri2b."
  steps/train_lda_mllt.sh --cmd "$train_cmd" \
    --splice-opts "--left-context=3 --right-context=3" \
    5500 90000 \
    data/gale/train data/lang exp/gale/tri1_ali exp/gale/tri2b || exit 1;
fi

if [ $stage -le 7 ]; then
  echo "$0: aligning with GALE lda and mllt adapted triphones $tri2b."
  steps/align_si.sh  --nj 56 \
    --cmd "$train_cmd" \
    --use-graphs true data/gale/train data/lang exp/gale/tri2b \
    exp/gale/tri2b_ali || exit 1;
fi

if [ $stage -le 8 ]; then
  echo "$0: Starting GALE SAT triphone training in exp/gale/tri3b."
  steps/train_sat.sh --cmd "$train_cmd" \
    5500 90000 \
    data/gale/train data/lang exp/gale/tri2b_ali exp/gale/tri3b || exit 1;
fi

if [ $stage -le 9 ]; then
  echo "$0: Starting GALE exp/tri3b_ali"
  steps/align_fmllr.sh --cmd "$train_cmd" --nj 56 data/gale/train data/lang \
    exp/gale/tri3b exp/gale/tri3b_ali || exit 1;
fi

exit 0
