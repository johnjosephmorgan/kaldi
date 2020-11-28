#!/usr/bin/env bash

. ./cmd.sh
. ./path.sh
stage=0

. ./utils/parse_options.sh

set -e
set -o pipefail
set -u

if [ $stage -le 0 ]; then
  echo "$0: Preparing the TRANSTAC Iraqi Arabic APPEN read 2005 training data."
  local/transtac/read/appen/2005/make_lists_train.pl || exit 1;
  utils/fix_data_dir.sh data/local/tmp/transtac/train/read/appen/2005/lists
fi

if [ $stage -le 1 ]; then
  echo "$0: Preparing the TRANSTAC read APPEN 2006 training data."
  local/transtac/read/appen/2006/make_lists_train.pl || exit 1;
  utils/fix_data_dir.sh data/local/tmp/transtac/train/read/appen/2006/lists
fi

if [ $stage -le 2 ]; then
  echo "$0: Preparing the TRANSTAC Iraqi Arabic Read Marine Acoustics 2006 training data."
  local/transtac/read/ma/2006/make_lists_train.pl || exit 1;
  utils/fix_data_dir.sh data/local/tmp/transtac/train/read/ma/2006/lists
fi

if [ $stage -le 3 ]; then
    echo "$0 Combine the 3 read speech corpora."
    read_dir=data/local/tmp/transtac/train/read
    utils/combine_data.sh data/transtac_read $read_dir/appen/2005/lists $read_dir/appen/2006/lists $read_dir/ma/2006/lists
fi

if [ $stage -le 4 ]; then
  echo "$0: Extract features from Transtac Read data."
  steps/make_mfcc.sh --cmd "$train_cmd" --nj 56 data/transtac_read
  steps/compute_cmvn_stats.sh data/transtac_read
  utils/fix_data_dir.sh data/transtac_read
fi

if [ $stage -le 5 ]; then
  echo "$0: Train monophones on transtac read Speech."
  steps/train_mono.sh  --cmd "$train_cmd" --nj 56 data/transtac_read \
		       data/lang exp/transtac_read/mono || exit 1;
fi

if [ $stage -le 6 ]; then
  echo "$0: aligning with transtac read monophones"
  steps/align_si.sh  --cmd "$train_cmd" --nj 56 data/transtac_read data/lang \
    exp/transtac_read/mono exp/transtac_read/mono_ali || exit 1;
fi

if [ $stage -le 7 ]; then
  echo "$0: Starting  transtac read triphone training in exp/gale/tri1."
  steps/train_deltas.sh --cmd "$train_cmd" --boost-silence 1.25 \
    5500 90000 \
    data/transtac_read data/lang exp/transtac_read/mono_ali exp/transtac_read/tri1 || exit 1;
fi

if [ $stage -le 8 ]; then
  echo "$0: Aligning with /transtac read triphones tri1."
  steps/align_si.sh  --cmd "$train_cmd" --nj 56 data/transtac_read data/lang \
		     exp/transtac_read/tri1 exp/transtac_read/tri1_ali || exit 1;
fi

if [ $stage -le 9 ]; then
  echo "$0: Starting transtac read lda_mllt triphone training in exp/transtac_read_appen_2006/tri2b."
  steps/train_lda_mllt.sh --cmd "$train_cmd" \
    --splice-opts "--left-context=3 --right-context=3" \
    5500 90000 \
    data/transtac_read data/lang exp/transtac_read/tri1_ali exp/transtac_read/tri2b || exit 1;
fi

if [ $stage -le 10 ]; then
  echo "$0: aligning with transtac read lda and mllt adapted triphones $tri2b."
  steps/align_si.sh  --nj 56 \
    --cmd "$train_cmd" \
    --use-graphs true data/transtac_read data/lang exp/transtac_read/tri2b \
    exp/transtac_read/tri2b_ali || exit 1;
fi

if [ $stage -le 11 ]; then
  echo "$0: Starting transtac read SAT triphone training in exp/transtac_read_appen_2006/tri3b."
  steps/train_sat.sh --cmd "$train_cmd" \
    5500 90000 \
    data/transtac_read data/lang exp/transtac_read/tri2b_ali exp/transtac_read/tri3b || exit 1;
fi
