#!/usr/bin/env bash

. ./cmd.sh
. ./path.sh
stage=0

. ./utils/parse_options.sh

set -e
set -o pipefail
set -u
tmpdir=data/local/tmp
transtac_tmpdir=$tmpdir/transtac

if [ $stage -le 0 ]; then
  echo "$0: Preparing the TRANSTAC Iraqi Arabic 2way APPEN 2006 training data."
  mkdir -p $transtac_tmpdir/train/twoway/appen/2006/lists
  local/transtac/twoway/appen/2006/make_lists_train.pl || exit 1;
  utils/fix_data_dir.sh $transtac_tmpdir/train/twoway/appen/2006/lists || exit 1;
fi

if [ $stage -le 1 ]; then
  echo "$0: Preparing the TRANSTAC Iraqi Arabic 2way APPEN 2007 training data."
  mkdir -p $transtac_tmpdir/train/twoway/appen/2007/lists
  local/transtac/twoway/appen/2007/make_lists_train.pl || exit 1;
  utils/fix_data_dir.sh $transtac_tmpdir/train/twoway/appen/2007/lists || exit 1;
fi

if [ $stage -le 2 ]; then
  echo "$0: Preparing the TRANSTAC Iraqi Arabic 2way DETROIT 2006 training data."
  mkdir -p $transtac_tmpdir/train/twoway/detroit/2006/lists
  local/transtac/twoway/detroit/2006/make_lists_train.pl || exit 1;
  utils/fix_data_dir.sh $transtac_tmpdir/train/twoway/detroit/2006/lists || exit 1;
fi

if [ $stage -le 3 ]; then
  echo "$0: Preparing the TRANSTAC Iraqi Arabic 2way DLI 2006 training data."
  mkdir -p $transtac_tmpdir/train/twoway/dli/2006/lists
  local/transtac/twoway/dli/2006/make_lists_train.pl || exit 1;
  utils/fix_data_dir.sh $transtac_tmpdir/train/twoway/dli/2006/lists || exit 1;
fi

if [ $stage -le 4 ]; then
  echo "$0: Preparing the TRANSTAC Iraqi Arabic 2way NIST 2007 training data."
  mkdir -p $transtac_tmpdir/train/twoway/nist/2007/lists
  local/transtac/twoway/nist/2007/make_lists_train.pl || exit 1;
  utils/fix_data_dir.sh $transtac_tmpdir/train/twoway/nist/2007/lists || exit 1;
fi

if [ $stage -le 5 ]; then
  echo "$0: Preparing the TRANSTAC Iraqi Arabic 2way Pendleton 2005 training data."
  mkdir -p $transtac_tmpdir/train/twoway/pendleton/2005/lists
  local/transtac/twoway/pendleton/2005/make_lists_train.pl || exit 1;
  utils/fix_data_dir.sh $transtac_tmpdir/train/twoway/pendleton/2005/lists || exit 1;
fi

if [ $stage -le 6 ]; then
  echo "$0: Preparing the TRANSTAC Iraqi Arabic 2way San Diego 2006 training data."
  mkdir -p $transtac_tmpdir/train/twoway/san_diego/2006/lists
  local/transtac/twoway/san_diego/2006/make_lists_train.pl || exit 1;
  utils/fix_data_dir.sh $transtac_tmpdir/train/twoway/san_diego/2006/lists || exit 1;
fi

if [ $stage -le 7 ]; then
  echo "$0 Combine the 7 2way speech corpora."
  twoway_dir=data/local/tmp/transtac/train/twoway
  utils/combine_data.sh \
      data/transtac_twoway \
    $twoway_dir/appen/2006/lists \
    $twoway_dir/appen/2007/lists \
    $twoway_dir/detroit/2006/lists \
    $twoway_dir/dli/2006/lists \
    $twoway_dir/nist/2007/lists \
    $twoway_dir/pendleton/2005/lists \
    $twoway_dir/san_diego/2006/liss
  utils/fix_data_dir.sh data/transtac_twoway || exit 1;
fi

if [ $stage -le 7 ]; then
    echo "$0: Extract features from transtac 2way data."
  steps/make_mfcc.sh --cmd "$train_cmd" --nj 56 data/transtac_twoway
  steps/compute_cmvn_stats.sh data/transtac_twoway
  utils/fix_data_dir.sh data/transtac_twoway || exit 1;
fi

if [ $stage -le 8 ]; then
  echo "$0: Train monophones on transtac 2way Speech."
  steps/train_mono.sh  --cmd "$train_cmd" --nj 56 data/transtac_twoway \
		       data/lang exp/transtac_twoway/mono || exit 1;
fi

if [ $stage -le 6 ]; then
  echo "$0: aligning with transtac read monophones"
  steps/align_si.sh  --cmd "$train_cmd" --nj 56 data/transtac_twoway data/lang \
    exp/transtac_twoway/mono exp/transtac_twoway/mono_ali || exit 1;
fi

if [ $stage -le 7 ]; then
  echo "$0: Starting  transtac read triphone training in exp/gale/tri1."
  steps/train_deltas.sh --cmd "$train_cmd" --boost-silence 1.25 \
    5500 90000 \
    data/transtac_twoway data/lang exp/transtac_twoway/mono_ali exp/transtac_twoway/tri1 || exit 1;
fi

if [ $stage -le 8 ]; then
  echo "$0: Aligning with /transtac read triphones tri1."
  steps/align_si.sh  --cmd "$train_cmd" --nj 56 data/transtac_twoway data/lang \
		     exp/transtac_twoway/tri1 exp/transtac_twoway/tri1_ali || exit 1;
fi

if [ $stage -le 9 ]; then
  echo "$0: Starting transtac read lda_mllt triphone training in exp/transtac_twoway_appen_2006/tri2b."
  steps/train_lda_mllt.sh --cmd "$train_cmd" \
    --splice-opts "--left-context=3 --right-context=3" \
    5500 90000 \
    data/transtac_twoway data/lang exp/transtac_twoway/tri1_ali exp/transtac_twoway/tri2b || exit 1;
fi

if [ $stage -le 10 ]; then
  echo "$0: aligning with transtac read lda and mllt adapted triphones $tri2b."
  steps/align_si.sh  --nj 56 \
    --cmd "$train_cmd" \
    --use-graphs true data/transtac_twoway data/lang exp/transtac_twoway/tri2b \
    exp/transtac_twoway/tri2b_ali || exit 1;
fi

if [ $stage -le 11 ]; then
  echo "$0: Starting transtac read SAT triphone training in exp/transtac_twoway_appen_2006/tri3b."
  steps/train_sat.sh --cmd "$train_cmd" \
    5500 90000 \
    data/transtac_twoway data/lang exp/transtac_twoway/tri2b_ali exp/transtac_twoway/tri3b || exit 1;
fi

if [ $stage -le 12 ]; then
  echo "$0: Starting transtac twoway alignment in exp/transtac_twoway/tri3b_ali"
  steps/align_fmllr.sh --cmd "$train_cmd" --nj 56 data/transtac_twoway/train \
    data/lang exp/transtac_twoway/tri3b exp/transtac_twoway/tri3b_ali || exit 1;
fi

