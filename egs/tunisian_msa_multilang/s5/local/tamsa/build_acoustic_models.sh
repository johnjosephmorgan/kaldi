#!/bin/bash
. ./cmd.sh
set -euo pipefail

# Begin Configuration variables settings
cmd=run.pl
stage=0
tmpdir=data/local/tmp
speech="http://www.openslr.org/resources/46/Tunisian_MSA.tar.gz"
lex="http://alt.qcri.org/resources/speech/dictionary/ar-ar_lexicon_2014-03-17.txt.bz2"
# end setting configuration variables

. ./path.sh
. ./cmd.sh
. ./utils/parse_options.sh

if [ $stage -le 1 ]; then
  local/tamsa/prepare_data.sh
fi

if [ $stage -le 3 ]; then
  mkdir -p $tmpdir/qcri/dict_init
  local/qcri_buckwalter2utf8.sh > $tmpdir/qcri/dict_init/qcri_utf8.txt
fi

if [ $stage -le 4 ]; then
  mkdir -p $tmpdir/tamsa/dict
  local/tamsa/prepare_dict.sh $tmpdir/qcri/dict_init/qcri_utf8.txt $tmpdir/tamsa/dict
  echo "<UNK> SPN" >> $tmpdir/tamsa/dict/lexicon.txt
fi

if [ $stage -le 5 ]; then
  echo "$0: Preparing the lang directory."
  utils/prepare_lang.sh $tmpdir/tamsa/dict "<UNK>" $tmpdir/tamsa/lang data/tamsa/lang
fi

if [ $stage -le 6 ]; then
  # extract acoustic features
  for fld in devtest train test; do
    steps/make_mfcc.sh data/tamsa/$fld exp/tamsa/make_mfcc/$fld mfcc_tamsa
    utils/fix_data_dir.sh data/tamsa/$fld
    steps/compute_cmvn_stats.sh data/tamsa/$fld exp/tamsa/make_mfcc mfcc_tamsa
    utils/fix_data_dir.sh data/tamsa/$fld
  done
fi

if [ $stage -le 7 ]; then
  echo "$0: Getting the shortest 500 utterances."
  utils/subset_data_dir.sh --shortest data/tamsa/train 500 data/tamsa/train_500short
fi

if [ $stage -le 8 ]; then
  echo "$0: monophone training"
  steps/train_mono.sh  data/tamsa/train data/tamsa/lang exp/tamsa/mono
fi

if [ $stage -le 9 ]; then
  echo "$0: aligning with monophones."
  steps/align_si.sh  data/tamsa/train data/tamsa/lang exp/tamsa/mono exp/tamsa/mono_ali
fi

if [ $stage -le 10 ]; then
  echo "$0: Starting  triphone training in exp/tri1"
  steps/train_deltas.sh \
    --boost-silence 1.25 1000 6000 data/tamsa/train data/tamsa/lang exp/tamsa/mono_ali exp/tamsa/tri1
fi

if [ $stage -le 11 ]; then
  echo "$0: aligning with triphones."
  steps/align_si.sh  data/tamsa/train data/tamsa/lang exp/tamsa/tri1 exp/tamsa/tri1_ali
fi

if [ $stage -le 12 ]; then
  echo "$0: Starting (lda_mllt) triphone training in exp/tri2b"
  steps/train_lda_mllt.sh \
    --splice-opts "--left-context=3 --right-context=3" 1000 6000 \
    data/tamsa/train data/tamsa/lang exp/tamsa/tri1_ali exp/tamsa/tri2b
fi

if [ $stage -le 13 ]; then
  echo "$0: aligning with lda and mllt adapted triphones."
  steps/align_si.sh \
    --use-graphs true data/tamsa/train data/tamsa/lang exp/tamsa/tri2b exp/tamsa/tri2b_ali
fi

if [ $stage -le 14 ]; then
  echo "$0: Starting (SAT) triphone training in exp/tri3b"
  steps/train_sat.sh 1000 6000 data/tamsa/train data/tamsa/lang exp/tamsa/tri2b_ali exp/tamsa/tri3b
fi

if [ $stage -le 15 ]; then
  echo "$0: Aligning tamsa with tri3b models."
  steps/align_fmllr.sh data/tamsa/train data/tamsa/lang exp/tamsa/tri3b exp/tamsa/tri3b_ali
fi
exit 0
