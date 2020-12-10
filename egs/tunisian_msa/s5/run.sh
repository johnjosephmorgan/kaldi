#!/bin/bash 

# Trains on 11 hours of speechfrom CTELL{ONE,TWO,THREE,FOUR,FIVE}
# Uses the ARL modified QCRI vowelized Arabic lexicon.
# Converts the Buckwalter encoding to utf8.
# Does not download the speech, lexicon and subs text data
# It assumes these corpora are available locally. 
. ./cmd.sh
. ./path.sh
lex=./lexicon.txt
stage=0
. ./utils/parse_options.sh
set -e
set -o pipefail
set -u
# Do not change tmpdir, other scripts under local depend on it
tmpdir=data/local/tmp

# preparation stages will store files under data/
# Delete the entire data directory when restarting.
if [ $stage -le 0 ]; then
  local/prepare_data.sh
fi

if [ $stage -le 1 ]; then
  mkdir -p $tmpdir/dict
  local/prepare_dict.sh $lex
fi

if [ $stage -le 2 ]; then
  # prepare the lang directory
  utils/prepare_lang.sh data/local/dict "<UNK>" data/local/lang data/lang
fi

if [ $stage -le 3 ]; then
  echo "Preparing the MFLTS transtac data for lm training."
  local/mflts/get_text.sh
  local/mflts/make_lists_train.pl
fi

if [ $stage -le 4 ]; then
  echo "$0: Consolidating Field Manuals text data with MFLTS Transtac text."
  mkdir -p data/local/tmp/fm
  mkdir -p data/local/tmp/lm
  cat ./fm5-0_ar.txt ./fm6-0_ar.txt ./fm6-22_ar.txt ./fm7-8_ar.txt > \
    data/local/tmp/fm/text
  cat data/local/tmp/fm/text data/local/tmp/mflts/train/lists/text > \
    data/local/tmp/lm/text
fi

if [ $stage -le 5 ]; then
  echo "lm training."
  local/prepare_lm.sh  $tmpdir/lm/text
fi

if [ $stage -le 6 ]; then
  echo "Making grammar fst."
  utils/format_lm.sh \
    data/lang data/local/lm/trigram.arpa.gz data/local/dict/lexicon.txt \
    data/lang_test
fi

if [ $stage -le 7 ]; then
  # extract acoustic features
  for fld in devtest train test; do
    steps/make_mfcc.sh data/$fld exp/make_mfcc/$fld mfcc
    utils/fix_data_dir.sh data/$fld
    steps/compute_cmvn_stats.sh data/$fld exp/make_mfcc mfcc
    utils/fix_data_dir.sh data/$fld
  done
fi

if [ $stage -le 8 ]; then
  echo "$0: monophone training"
  steps/train_mono.sh  data/train data/lang exp/mono
fi

if [ $stage -le 9 ]; then
  echo "$0: aligning with monophones."
  steps/align_si.sh  data/train data/lang exp/mono exp/mono_ali
fi

if [ $stage -le 10 ]; then
  echo "$0: Starting  triphone training in exp/tri1"
  steps/train_deltas.sh \
    --boost-silence 1.25 1000 6000 data/train data/lang exp/mono_ali exp/tri1
fi

if [ $stage -le 11 ]; then
  echo "$0: Align with triphones."
  steps/align_si.sh  data/train data/lang exp/tri1 exp/tri1_ali
fi

if [ $stage -le 12 ]; then
  echo "$0: Starting (lda_mllt) triphone training in exp/tri2b"
  steps/train_lda_mllt.sh \
    --splice-opts "--left-context=3 --right-context=3" 500 5000 \
    data/train data/lang exp/tri1_ali exp/tri2b
fi


if [ $stage -le 13 ]; then
  echo "$0: align with lda and mllt adapted triphones."
  steps/align_si.sh \
    --use-graphs true data/train data/lang exp/tri2b exp/tri2b_ali
fi

if [ $stage -le 14 ]; then
  echo "$0: Starting (SAT) triphone training in exp/tri3b"
  steps/train_sat.sh 800 8000 data/train data/lang exp/tri2b_ali exp/tri3b
fi

if [ $stage -le 15 ]; then
  (
    echo "$0: make decoding graphs for SAT models."
    utils/mkgraph.sh data/lang_test exp/tri3b exp/tri3b/graph

    # decode test sets with tri3b models
    for x in devtest test; do
      nspk=$(wc -l < data/$x/spk2utt)
      steps/decode_fmllr.sh --nj $nspk exp/tri3b/graph data/$x exp/tri3b/decode_${x}
    done
  ) &
fi

if [ $stage -le 16 ]; then
  echo "$0: Align with tri3b models."
  steps/align_fmllr.sh data/train data/lang exp/tri3b exp/tri3b_ali
fi

if [ $stage -le 17 ]; then
  # train and test chain models
  local/chain/run_tdnn.sh
fi
