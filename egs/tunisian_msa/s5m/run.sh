#!/usr/bin/env bash 

# Tunisian MSA  and 1 Libyan accented speaker

. ./cmd.sh
. ./path.sh
stage=0

. ./utils/parse_options.sh

set -e
set -o pipefail
set u

tmpdir=data/local/tmp
lexicon=/mnt/corpora/Tunisian_MSA/lexicon.txt

if [ $stage -le 0 ]; then
  local/prepare_data.sh || exit 1;
fi

if [ $stage -le 1 ]; then
  mkdir -p $tmpdir/dict
  local/prepare_dict.sh $lexicon
fi

if [ $stage -le 2 ]; then
  # prepare the lang directory
  utils/prepare_lang.sh data/local/dict "<UNK>" data/local/lang data/lang
fi

if [ $stage -le 3 ]; then
  # extract acoustic features
  for fld in devtest train test; do
    steps/make_mfcc.sh data/$fld exp/make_mfcc/$fld mfcc
    utils/fix_data_dir.sh data/$fld
    steps/compute_cmvn_stats.sh data/$fld exp/make_mfcc mfcc
    utils/fix_data_dir.sh data/$fld
  done
fi

if [ $stage -le 4 ]; then
  echo "$0: monophone training"
  steps/train_mono.sh  data/train data/lang exp/mono
fi

if [ $stage -le 5 ]; then
  # align with monophones
  steps/align_si.sh  data/train data/lang exp/mono exp/mono_ali
fi

if [ $stage -le 6 ]; then
  echo "$0: Starting  triphone training in exp/tri1"
  steps/train_deltas.sh \
    --boost-silence 1.25 1000 6000 data/train data/lang exp/mono_ali exp/tri1
fi

if [ $stage -le 7 ]; then
  # align with triphones
  steps/align_si.sh  data/train data/lang exp/tri1 exp/tri1_ali
fi

if [ $stage -le 8 ]; then
  echo "$0: Starting (lda_mllt) triphone training in exp/tri2b"
  steps/train_lda_mllt.sh \
    --splice-opts "--left-context=3 --right-context=3" 500 5000 \
    data/train data/lang exp/tri1_ali exp/tri2b
fi

if [ $stage -le 9 ]; then
  # align with lda and mllt adapted triphones
  steps/align_si.sh \
    --use-graphs true data/train data/lang exp/tri2b exp/tri2b_ali
fi

if [ $stage -le 10 ]; then
  echo "$0: Starting (SAT) triphone training in exp/tri3b"
  steps/train_sat.sh 800 8000 data/train data/lang exp/tri2b_ali exp/tri3b
fi

if [ $stage -le 11 ]; then
  # align with tri3b models
  echo "$0: Starting exp/tri3b_ali"
  steps/align_fmllr.sh data/train data/lang exp/tri3b exp/tri3b_ali
fi

if [ $stage -le 12 ]; then
  echo "$0: lm training."
  rm -Rf data/local/lm
  local/gale_train_lms_utf8.sh \
    ../../gale_arabic/s5d/data/train/text \
    data/local/lexicon_data/lexicon.bw \
    data/local/lm || exit 1; 
fi

if [ $stage -le 13 ]; then
  echo "Making grammar fst."
  local/format_lm_utf8.sh
fi

if [ $stage -le 14 ]; then
  (
    # make decoding graphs for SAT models
    utils/mkgraph.sh \
      data/lang_test \
      exp/tri3b \
      exp/tri3b/graph || exit 1;

    # decode test sets with tri3b models
    for x in devtest test; do
      nspk=$(wc -l < data/$x/spk2utt)
      steps/decode_fmllr.sh \
        --nj $nspk \
        exp/tri3b/graph \
        data/$x \
        exp/tri3b/decode_${x} || exit 1;
    done
  ) &
fi

if [ $stage -le 15 ]; then
    # train and test chain models
  local/chain/run_tdnn.sh
fi
