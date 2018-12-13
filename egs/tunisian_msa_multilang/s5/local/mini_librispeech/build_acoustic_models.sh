#!/bin/bash
. ./cmd.sh
set -euo pipefail

# Begin Configuration variables settings
cmd=run.pl
stage=0
tmpdir=data/local/tmp
# Variables for mini librispeech
data=data_librispeech
# End of Configuration variables settings

. ./path.sh
. ./cmd.sh
. ./utils/parse_options.sh

if [ $stage -le 1 ]; then
echo "Cooking with mini_librispeech recipe."
  for part in dev-clean-2 train-clean-5; do
    echo "Formatting the $part data as Kaldi data directories."
    # use underscore-separated names in data directories.
    local/mini_librispeech/data_prep.sh $data/LibriSpeech/$part data/mini_librispeech/$(echo $part | sed s/-/_/g)
  done
  utils/copy_data_dir.sh data/mini_librispeech/train_clean_5 data/mini_librispeech/train
fi

if [ $stage -le 2 ]; then
  mkdir -p $tmpdir/mini_librispeech/lm
  cut -d " " -f 2- data/mini_librispeech/train/text > $tmpdir/mini_librispeech/lm/train.txt
  local/mini_librispeech/prepare_small_lm.sh $tmpdir/mini_librispeech/lm/train.txt
  tr " " "\n" < $tmpdir/mini_librispeech/lm/train.txt | sort -u > $tmpdir/mini_librispeech/lm/librispeech-vocab.txt

  local/mini_librispeech/prepare_dict.sh $tmpdir/mini_librispeech/dict
  echo "<UNK> SPN" >> $tmpdir/mini_librispeech/dict/lexicon.txt
fi

if [ $stage -le 3 ]; then
  utils/prepare_lang.sh $tmpdir/mini_librispeech/dict \
    "<UNK>" $tmpdir/mini_librispeech/lang_tmp data/mini_librispeech/lang
fi

if [ $stage -le 4 ]; then
  mfccdir=mfcc_librispeech
  for part in dev_clean_2 train_clean_5 train; do
    steps/make_mfcc.sh --cmd "$train_cmd" --nj 40 data/mini_librispeech/$part exp/mini_librispeech/make_mfcc/$part $mfccdir
    steps/compute_cmvn_stats.sh data/mini_librispeech/$part exp/mini_librispeech/make_mfcc/$part $mfccdir
  done
fi

if [ $stage -le 5 ]; then
    echo "Getting the shortest 500 utterances."
  utils/subset_data_dir.sh --shortest data/mini_librispeech/train_clean_5 500 data/mini_librispeech/train_500short
fi

if [ $stage -le 6 ]; then
  echo "Training a monophone system."
  steps/train_mono.sh --boost-silence 1.25 --nj 4 --cmd "$train_cmd" \
    data/mini_librispeech/train_500short data/mini_librispeech/lang exp/mini_librispeech/mono
fi

if [ $stage -le 7 ]; then
  steps/align_si.sh --boost-silence 1.25 --nj 29 --cmd "$train_cmd" \
    data/mini_librispeech/train_clean_5 data/mini_librispeech/lang exp/mini_librispeech/mono exp/mini_librispeech/mono_ali_train
fi

if [ $stage -le 8 ]; then
  echo "Training a first delta + delta-delta triphone system."
  steps/train_deltas.sh --boost-silence 1.25 --cmd "$train_cmd" \
    1000 6000 data/mini_librispeech/train_clean_5 data/mini_librispeech/lang \
    exp/mini_librispeech/mono_ali_train exp/mini_librispeech/tri1
fi

if [ $stage -le 9 ]; then
  steps/align_si.sh --nj 29 --cmd "$train_cmd" \
    data/mini_librispeech/train_clean_5 data/mini_librispeech/lang exp/mini_librispeech/tri1 exp/mini_librispeech/tri1_ali_train
fi

if [ $stage -le 10 ]; then
  echo "Training an LDA+MLLT system."
  steps/train_lda_mllt.sh --cmd "$train_cmd" \
    --splice-opts "--left-context=3 --right-context=3" 1500 10000 \
    data/mini_librispeech/train_clean_5 data/mini_librispeech/lang exp/mini_librispeech/tri1_ali_train exp/mini_librispeech/tri2b
fi

if [ $stage -le 11 ]; then
  echo "Aligning utts using the tri2b model."
  steps/align_si.sh  --nj 29 --cmd "$train_cmd" --use-graphs true \
    data/mini_librispeech/train_clean_5 data/mini_librispeech/lang exp/mini_librispeech/tri2b exp/mini_librispeech/tri2b_ali_train
fi

if [ $stage -le 12 ]; then
  echo "Training tri3b, which is LDA+MLLT+SAT."
  steps/train_sat.sh --cmd "$train_cmd" 1500 10000 \
    data/mini_librispeech/train_clean_5 data/mini_librispeech/lang exp/mini_librispeech/tri2b_ali_train exp/mini_librispeech/tri3b
fi

if [ $stage -le 13 ]; then
  echo "$0: Starting exp/tri3b_ali"
  steps/align_fmllr.sh --nj 29 --cmd "$train_cmd" \
    data/mini_librispeech/train_clean_5 data/mini_librispeech/lang exp/mini_librispeech/tri3b exp/mini_librispeech/tri3b_ali
fi
exit 0
