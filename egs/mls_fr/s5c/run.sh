#!/usr/bin/env bash

# Multilingual Libri speech French
# Train on part of the train set
# 100k utterances
data=/mnt/corpora/MLS_French
mfccdir=mfcc
tmp_dir=data/local/tmp
g2p_input_text_files="data/dev/text data/train/text"

stage=0

. ./cmd.sh
. ./path.sh
. parse_options.sh

# you might not want to do this for interactive shells.
set -e

if [ $stage -le 0 ]; then
  echo "$0: Data Preparation."
  for f in dev test train; do
    local/data_prep.sh $data/$f data/$f
  done
fi

if [ $stage -le 1 ]; then
  echo "$0: Prepare lexicon as in yaounde recipe."
  mkdir -p data/local/tmp/dict
  export LC_ALL=C
  local/prepare_dict.sh \
    local/dict/santiago.txt \
    $tmp_dir/dict/init || exit 1;
fi

if [ $stage -le 2 ]; then
  echo "$0: Training a g2p model."
  local/g2p/train_g2p.sh \
    $tmp_dir/dict/init \
    $tmp_dir/dict/g2p || exit 1;
fi

if [ $stage -le 3 ]; then
  echo "$0: Applying the g2p."
  local/g2p/apply_g2p.sh \
    $tmp_dir/dict/g2p/model.fst \
    $tmp_dir/dict/work \
    $tmp_dir/dict/init/lexicon.txt \
    $tmp_dir/dict/init/lexicon_with_tabs.txt \
    $g2p_input_text_files || exit 1;
fi

if [ $stage -le 4    ]; then
  echo "$0: Delimiting fields with space instead of tabs."
  mkdir -p $tmp_dir/dict/final
  expand -t 1 \
    $tmp_dir/dict/init/lexicon_with_tabs.txt > \
    $tmp_dir/dict/final/lexicon.txt
fi

if [ $stage -le 5    ]; then
  echo "$0: Preparing expanded lexicon."
  local/prepare_dict.sh \
    $tmp_dir/dict/final/lexicon.txt \
    data/local/dict || exit 1;
  echo "$0: Adding <UNK> to the lexicon."
  echo "<UNK> SPN" >> data/local/dict/lexicon.txt
fi

if [ $stage -le 6 ]; then
  echo "$0: Preparing lang directory."
  utils/prepare_lang.sh \
    --position-dependent-phones true \
    data/local/dict \
    "<UNK>" \
    data/local/lang_tmp \
    data/lang || exit 1;
fi

if [ $stage -le 7 ]; then
  echo "$0: Preparing the lm."
  mkdir -p $tmp_dir/lm
  mkdir -p data/local/lm
  cut -f 2- data/dev/text > $tmp_dir/lm/text
  cut -f 2- data/train/text >> $tmp_dir/lm/text
  local/prepare_lm.sh  $tmp_dir/lm/text || exit 1;
fi

if [ $stage -le 8 ]; then
  echo "$0: Make the G.fst."
  local/format_lms.sh \
    --src-dir data/lang \
    data/local/lm
fi

if [ $stage -le 9 ]; then
  for part in dev test train; do
    echo "$0: Extracting features for $part."
    steps/make_mfcc.sh --cmd "$train_cmd" --nj 40 data/$part exp/make_mfcc/$part $mfccdir
    steps/compute_cmvn_stats.sh data/$part exp/make_mfcc/$part $mfccdir
  done
fi

if [ $stage -le 10 ]; then
  echo "$0: Make some small data subsets for early system-build stages."
  # For the monophone stages we select the shortest utterances, which should make it
  # easier to align the data from a flat start.
  utils/subset_data_dir.sh --shortest data/train 2000 data/train_2kshort
  utils/subset_data_dir.sh data/train 5000 data/train_5k
  utils/subset_data_dir.sh data/train 25000 data/train_25k
  utils/subset_data_dir.sh data/train 100000 data/train_100k
fi

if [ $stage -le 11 ]; then
  steps/train_mono.sh \
    --boost-silence 1.25 \
    --nj 20 \
    --cmd "$train_cmd" \
    data/train_2kshort \
    data/lang \
    exp/mono
fi

if [ $stage -le 12 ]; then
  steps/align_si.sh \
    --boost-silence 1.25 \
    --nj 10 \
    --cmd "$train_cmd" \
    data/train_5k \
    data/lang \
    exp/mono \
    exp/mono_ali_5k

  # train a first delta + delta-delta triphone system on a subset of 1000 utterances
  steps/train_deltas.sh \
    --boost-silence 1.25 \
    --cmd "$train_cmd" \
    2000 10000 \
    data/train_5k \
    data/lang \
    exp/mono_ali_5k \
    exp/tri1
fi

if [ $stage -le 13 ]; then
  steps/align_si.sh \
    --nj 10 \
    --cmd "$train_cmd" \
    data/train_25k \
    data/lang \
    exp/tri1 \
    exp/tri1_ali_25k

  # train an LDA+MLLT system.
  steps/train_lda_mllt.sh \
    --cmd "$train_cmd" \
    --splice-opts "--left-context=3 --right-context=3" \
    2500 15000 \
    data/train_25k \
    data/lang \
    exp/tri1_ali_25k \
    exp/tri2b
fi

if [ $stage -le 14 ]; then
  # Align a 100k utts subset using the tri2b model
  steps/align_si.sh  \
    --nj 10 \
    --cmd "$train_cmd" \
    --use-graphs true \
    data/train_100k \
    data/lang \
    exp/tri2b \
    exp/tri2b_ali_100k || exit 1;

  # Train tri3b, which is LDA+MLLT+SAT 
  steps/train_sat.sh \
    --cmd "$train_cmd" \
    2500 15000 \
    data/train_100k \
    data/lang \
    exp/tri2b_ali_100k \
    exp/tri3b || exit 1;
fi

if [ $stage -le 15 ]; then
  # Now we compute the pronunciation and silence probabilities from training data,
  # and re-create the lang directory.
  steps/get_prons.sh \
    --cmd "$train_cmd" \
    data/train_100k \
    data/lang \
    exp/tri3b
fi

if [ $stage -le 16 ]; then
  utils/dict_dir_add_pronprobs.sh \
    --max-normalize true \
    data/local/dict \
    exp/tri3b/pron_counts_nowb.txt \
    exp/tri3b/sil_counts_nowb.txt \
    exp/tri3b/pron_bigram_counts_nowb.txt \
    data/local/dict_with_new_prons
fi

if [ $stage -le 17 ]; then
  utils/prepare_lang.sh \
    data/local/dict_with_new_prons \
    "<UNK>" \
    data/local/lang_tmp \
    data/lang
fi

if [ $stage -le 18 ]; then
  local/format_lms.sh \
    --src-dir data/lang \
    data/local/lm
fi

if [ $stage -le  19 ]; then
  steps/align_fmllr.sh \
    --cmd "$train_cmd" \
    --nj 34 \
    data/train_100k \
    data/lang \
    exp/tri3b \
    exp/tri3b_ali || exit 1;
fi

if [ $stage -le 20 ]; then
  # decode using the tri3b model
  utils/mkgraph.sh \
    data/lang_test \
    exp/tri3b \
    exp/tri3b/graph
fi

if [ $stage -le 21 ]; then
  for test in test dev; do
  steps/decode_fmllr.sh \
    --cmd "$decode_cmd" \
    --nj 20 \
    exp/tri3b/graph \
    data/$test \
    exp/tri3b/decode_$test
  done
fi

if [ $stage -le 22 ]; then
  # train and test nnet3 tdnn models 
  local/chain/tuning/run_tdnn_1g.sh
fi