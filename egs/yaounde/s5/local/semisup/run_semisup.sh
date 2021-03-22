#!/bin/bash

# Copyright 2017  Vimal Manohar
# Apache 2.0

# This script demonstrates semi-supervised training
# We assume the supervised data is in data/train_sup and unsupervised data
# is in data/train_unsup100k_250k. 
# For LM training, we assume there is data/train/text, from which
# we will exclude the utterances contained in the unsupervised set.
# We use all 300 hours of semi-supervised data for i-vector extractor training.

# This differs from run_100k.sh, which uses only 100 hours supervised data for 
# both i-vector extractor training and LM training.

. ./cmd.sh
. ./path.sh 

set -o pipefail
exp_root=exp/semisup

stage=0

. utils/parse_options.sh

###############################################################################
# Prepare semi-supervised train set 
###############################################################################

###############################################################################
# Train LM on all the text in data/train/text, but excluding the 
# utterances in the unsupervised set
###############################################################################
if [ $stage -le 0 ]; then
  mkdir -p data/local/pocolm

  local/train_lms_pocolm.sh \
    --text data/local/tmp/subs/lm/fr.txt \
    --dir data/local/lm
fi

if [ $stage -le 1 ]; then
  local/create_test_lang.sh \
    --arpa-lm data/local/lm/data/arpa/4gram_small.arpa.gz \
    --dir data/lang_test_poco
fi

if [ $stage -le 2 ]; then
  utils/build_const_arpa_lm.sh \
    data/local/lm/data/arpa/4gram_big.arpa.gz \
    data/lang_test_poco data/lang_test_poco_big
fi

###############################################################################
# Prepare lang directories with UNK modeled using phone LM
###############################################################################

if [ $stage -le 3 ]; then
  local/run_unk_model.sh || exit 1
fi

if [ $stage -le 4 ]; then
  for lang_dir in data/lang_test_poco; do
    rm -r ${lang_dir}_unk ${lang_dir}_unk_big 2>/dev/null || true
    cp -rT data/lang_unk ${lang_dir}_unk
    cp ${lang_dir}/G.fst ${lang_dir}_unk/G.fst
    cp -rT data/lang_unk ${lang_dir}_unk_big
    cp ${lang_dir}_big/G.carpa ${lang_dir}_unk_big/G.carpa; 
  done
fi

###############################################################################
# Train seed chain system using 50 hours supervised data.
# Here we train i-vector extractor on combined supervised and unsupervised data
###############################################################################

if [ $stage -le 5 ]; then
  for g in a b; do
    local/semisup/chain/run_tdnn.sh \
      --train-set train_${g} \
      --ivector-train-set train_${g} \
      --nnet3-affix _semi_${g} \
      --chain-affix _semi_${g} \
      --tdnn-affix _1a_${g} --tree-affix bi_a_${g} \
      --gmm tri3b_${g} --exp-root $exp_root || exit 1
  done
fi

###############################################################################
# Semi-supervised training using  supervised  and  unsupervised data. We use i-vector extractor, tree, lattices 
# and seed chain system from the previous stage.
###############################################################################

if [ $stage -le 6 ]; then
  local/semisup/chain/run_tdnn_semisupervised.sh \
    --supervised-set train_sup50k \
    --unsupervised-set train_unsup100k_250k \
    --sup-chain-dir $exp_root/chain_semi50k_100k_250k/tdnn_1a_sp \
    --sup-lat-dir $exp_root/chain_semi50k_100k_250k/tri4a_train_sup50k_sp_unk_lats \
    --sup-tree-dir $exp_root/chain_semi50k_100k_250k/tree_bi_a \
    --ivector-root-dir $exp_root/nnet3_semi50k_100k_250k \
    --chain-affix _semi50k_100k_250k \
    --tdnn-affix _semisup_1a \
    --exp-root $exp_root || exit 1

  # WER on dev                          18.98
  # WER on test                         18.85
  # Final output-0 train prob           -0.1381
  # Final output-0 valid prob           -0.1723
  # Final output-0 train prob (xent)    -1.3676
  # Final output-0 valid prob (xent)    -1.4589
  # Final output-1 train prob           -0.7671
  # Final output-1 valid prob           -0.7714
  # Final output-1 train prob (xent)    -1.1480
  # Final output-1 valid prob (xent)    -1.2382
fi

###############################################################################
# Oracle system trained on combined 300 hours including both supervised and 
# unsupervised sets. We use i-vector extractor, tree, and GMM trained
# on only the supervised for fair comparison to semi-supervised experiments.
###############################################################################

if [ $stage -le 11 ]; then
  local/semisup/chain/run_tdnn.sh \
    --train-set semisup50k_100k_250k \
    --nnet3-affix _semi50k_100k_250k \
    --chain-affix _semi50k_100k_250k \
    --common-treedir $exp_root/chain_semi50k_100k_250k/tree_bi_a \
    --tdnn-affix 1a_oracle --nj 100 \
    --gmm tri4a --exp-root $exp_root \
    --stage 9 || exit 1

  # WER on dev                          17.55
  # WER on test                         17.72
  # Final output train prob             -0.1155
  # Final output valid prob             -0.1510
  # Final output train prob (xent)      -1.7458
  # Final output valid prob (xent)      -1.9045
fi
