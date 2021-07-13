#!/bin/bash -e

num_jobs=60
num_decode_jobs=60
decode_gmm=false
stage=0
overwrite=true

# Training: 941h Testing: 10.4h

galeData=GALE
mgb2_dir=""
giga_dir=""

LM="gale_giga.o4g.kn.gz"
[ -z $giga_dir ] && LM="gale.o4g.kn.gz"

# preference on how to process xml file (use xml binary or python)
process_xml=""

run_rnnlm=false
. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.
. ./path.sh
. ./utils/parse_options.sh  # e.g. this parses the above options
                            # if supplied.

if [ $stage -le 0 ]; then
  if [ -f data/train/text ] && ! $overwrite; then
    echo "$0: Not processing, probably script have run from wrong stage"
    echo "Exiting with status 1 to avoid data corruption"
    exit 1;
  fi

  echo "$0: Preparing data..."

  options=""
  [ ! -z $mgb2_dir ] && options="--process-xml python --mgb2-dir $mgb2_dir"
  local/prepare_data.sh $options
fi

if [ $stage -le 1 ]; then
  echo "$0: Preparing lexicon and LM..." 
  local/prepare_dict.sh
fi

if [ $stage -le 2 ]; then
  utils/prepare_lang.sh data/local/dict "<UNK>" data/local/lang data/lang
fi

if [ $stage -le 3 ]; then
  local/gale_train_lms.sh data/train/text data/local/dict/lexicon.txt data/local/lm $giga_dir  # giga is Arabic Gigawords
fi

if [ $stage -le 4 ]; then
  utils/format_lm.sh data/lang data/local/lm/$LM \
    data/local/dict/lexicon.txt data/lang_test
fi

mfccdir=mfcc
if [ $stage -le 5 ]; then
  echo "$0: Preparing the test and train feature files..."
  for x in dev test_p2 mt_all train; do
    utils/fix_data_dir.sh data/$x
    steps/make_mfcc.sh --cmd "$train_cmd" --nj $num_jobs \
      data/$x exp/make_mfcc/$x $mfccdir
    utils/fix_data_dir.sh data/$x # some files fail to get mfcc for many reasons
    steps/compute_cmvn_stats.sh data/$x exp/make_mfcc/$x $mfccdir
  done
fi

if [ $stage -le 6 ]; then
  echo "$0: creating sub-set and training monophone system"
  utils/subset_data_dir.sh data/train 10000 data/train.10K || exit 1;
  utils/subset_data_dir.sh data/train 20000 data/train.20K || exit 1;
  utils/subset_data_dir.sh data/train 30000 data/train.30K || exit 1;
  utils/subset_data_dir.sh data/train 50000 data/train.50K || exit 1;
  utils/subset_data_dir.sh data/train 100000 data/train.100K || exit 1;
fi


if [ $stage -le 7 ]; then
    steps/train_mono.sh \
    --cmd "$train_cmd" \
    --nj 40 \
    data/train.10K \
    data/lang \
    exp/mono || exit 1;
fi

if [ $stage -le 7 ]; then
  echo "$0: Aligning data using monophone system"
  steps/align_si.sh \
    --cmd "$train_cmd" \
    --nj $num_jobs \
    data/train.20k \
    data/lang \
    exp/mono \
    exp/mono_ali || exit 1;

  echo "$0: training triphone system with delta features"
  steps/train_deltas.sh \
    --cmd "$train_cmd" \
    2500 30000 \
    data/train.20k \
    data/lang \
    exp/mono_ali \
    exp/tri1 || exit 1;
fi

if [ $stage -le 8 ] && $decode_gmm; then
  echo "$0: Aligning data and retraining and realigning with lda_mllt"
  steps/align_si.sh \
    --cmd "$train_cmd" \
    --nj $num_jobs \
    data/train.30k \
    data/lang \
    exp/tri1 \
    exp/tri1_ali || exit 1;

  steps/train_lda_mllt.sh \
    --cmd "$train_cmd" \
    4000 50000 \
    data/train.30k \
    data/lang \
    exp/tri1_ali \
    exp/tri2b || exit 1;
fi

if [ $stage -le 10 ] && $decode_gmm; then
  echo "$0: Aligning data and retraining and realigning with sat_basis"
  steps/align_si.sh \
    --cmd "$train_cmd" \
    --nj $num_jobs \
    data/train.50k \
    data/lang \
    exp/tri2b \
    exp/tri2b_ali || exit 1;

  steps/train_sat_basis.sh \
    --cmd "$train_cmd" \
    5000 100000 \
    data/train.50k \
    data/lang \
    exp/tri2b_ali \
    exp/tri3b || exit 1;

  steps/align_fmllr.sh \
    --cmd "$train_cmd" \
    --nj $num_jobs \
    data/train.100k \
    data/lang \
    exp/tri3b \
    exp/tri3b_ali || exit 1;
fi

if [ $stage -le 12 ] && $decode_gmm; then
  echo "$0: Training a regular chain model using the e2e alignments..."
  local/chain/run_tdnn.sh
fi

if [ $stage -le 14 ] && $run_rnnlm; then
  local/rnnlm/run_tdnn_lstm.sh
fi

echo "$0: training succeeded"
exit 0
#!/bin/bash -e

# Copyright 2014 QCRI (author: Ahmed Ali)
#           2019 Dongji Gao
# Apache 2.0

# This is the recipe for GALE Arabic speech translation project.
# It is similar to gale_arabic/s5b but with more training data.

num_jobs=60
num_decode_jobs=60
decode_gmm=false
stage=0
overwrite=true

# GALE Arabic phase 2 Conversation Speech
dir1=/mnt/corpora/LDC2013S02/          # checked
dir2=/mnt/corpora/LDC2013S07/          # checked (16k)
text1=/mnt/corpora/LDC2013T04/         # checked
text2=/mnt/corpora/LDC2013T17/         # checked
# GALE Arabic phase 2 News Speech
dir3=/mnt/corpora/LDC2014S07/          # checked (16k)
dir4=/mnt/corpora/LDC2015S01/          # checked (16k)
text3=/mnt/corpora/LDC2014T17/         # checked
text4=/mnt/corpora/LDC2015T01/         # checked
# GALE Arabic phase 3 Conversation Speech
dir5=/mnt/corpora/LDC2015S11/          # checked (16k)
dir6=/mnt/corpora/LDC2016S01/          # checked (16k)
text5=/mnt/corpora/LDC2015T16/         # checked
text6=/mnt/corpora/LDC2016T06/         # checked
# GALE Arabic phase 3 News Speech
dir7=/mnt/corpora/LDC2016S07/          # checked (16k)
dir8=/mnt/corpora/LDC2017S02/          # checked (16k)
text7=/mnt/corpora/LDC2016T17/         # checked
text8=/mnt/corpora/LDC2017T04/         # checked
# GALE Arabic phase 4 Conversation Speech
dir9=/mnt/corpora/LDC2017S15/          # checked (16k)
text9=/mnt/corpora/LDC2017T12/         # checked
# GALE Arabic phase 4 News Speech
dir10=/mnt/corpora/LDC2018S05/          # checked (16k)
text10=/mnt/corpora/LDC2018T14/         # checked

# Training: 941h Testing: 10.4h

galeData=GALE
mgb2_dir=""
giga_dir=""

if [[ $(hostname -f) == *.clsp.jhu.edu ]]; then giga_dir="GIGA"; fi

LM="gale_giga.o4g.kn.gz"
[ -z $giga_dir ] && LM="gale.o4g.kn.gz"

# preference on how to process xml file (use xml binary or python)
process_xml=""

run_rnnlm=false
. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.
. ./path.sh
. ./utils/parse_options.sh  # e.g. this parses the above options
                            # if supplied.

if [ $stage -le 0 ]; then

  if [ -f data/train/text ] && ! $overwrite; then
    echo "$0: Not processing, probably script have run from wrong stage"
    echo "Exiting with status 1 to avoid data corruption"
    exit 1;
  fi

  echo "$0: Preparing data..."

  options=""
  [ ! -z $mgb2_dir ] && options="--process-xml python --mgb2-dir $mgb2_dir"
  local/prepare_data.sh $options
fi

if [ $stage -le 1 ]; then
  echo "$0: Preparing lexicon and LM..." 
  local/prepare_dict.sh
fi

if [ $stage -le 2 ]; then
  utils/prepare_lang.sh data/local/dict "<UNK>" data/local/lang data/lang
fi

if [ $stage -le 3 ]; then
  local/gale_train_lms.sh data/train/text data/local/dict/lexicon.txt data/local/lm $giga_dir  # giga is Arabic Gigawords
fi

if [ $stage -le 4 ]; then
  utils/format_lm.sh data/lang data/local/lm/$LM \
    data/local/dict/lexicon.txt data/lang_test
fi

mfccdir=mfcc
if [ $stage -le 5 ]; then
  echo "$0: Preparing the test and train feature files..."
  for x in dev test_p2 mt_all train; do
    utils/fix_data_dir.sh data/$x
    steps/make_mfcc.sh --cmd "$train_cmd" --nj $num_jobs \
      data/$x exp/make_mfcc/$x $mfccdir
    utils/fix_data_dir.sh data/$x # some files fail to get mfcc for many reasons
    steps/compute_cmvn_stats.sh data/$x exp/make_mfcc/$x $mfccdir
  done
fi

if [ $stage -le 6 ]; then
  echo "$0: creating sub-set and training monophone system"
  utils/subset_data_dir.sh data/train 10000 data/train.10K || exit 1;

  steps/train_mono.sh --nj 40 --cmd "$train_cmd" \
    data/train.10K data/lang exp/mono || exit 1;
fi

if [ $stage -le 7 ]; then
  echo "$0: Aligning data using monophone system"
  steps/align_si.sh --nj $num_jobs --cmd "$train_cmd" \
    data/train data/lang exp/mono exp/mono_ali || exit 1;

  echo "$0: training triphone system with delta features"
  steps/train_deltas.sh --cmd "$train_cmd" \
    2500 30000 data/train data/lang exp/mono_ali exp/tri1 || exit 1;
fi

if [ $stage -le 8 ] && $decode_gmm; then
  utils/mkgraph.sh data/lang_test exp/tri1 exp/tri1/graph
  steps/decode.sh  --nj $num_decode_jobs --cmd "$decode_cmd" \
    exp/tri1/graph data/dev exp/tri1/decode
fi

if [ $stage -le 9 ]; then
  echo "$0: Aligning data and retraining and realigning with lda_mllt"
  steps/align_si.sh --nj $num_jobs --cmd "$train_cmd" \
    data/train data/lang exp/tri1 exp/tri1_ali || exit 1;

  steps/train_lda_mllt.sh --cmd "$train_cmd" 4000 50000 \
    data/train data/lang exp/tri1_ali exp/tri2b || exit 1;
fi

if [ $stage -le 10 ] && $decode_gmm; then
  utils/mkgraph.sh data/lang_test exp/tri2b exp/tri2b/graph
  steps/decode.sh --nj $num_decode_jobs --cmd "$decode_cmd" \
    exp/tri2b/graph data/dev exp/tri2b/decode
fi

if [ $stage -le 11 ]; then
  echo "$0: Aligning data and retraining and realigning with sat_basis"
  steps/align_si.sh --nj $num_jobs --cmd "$train_cmd" \
    data/train data/lang exp/tri2b exp/tri2b_ali || exit 1;

  steps/train_sat_basis.sh --cmd "$train_cmd" \
    5000 100000 data/train data/lang exp/tri2b_ali exp/tri3b || exit 1;

  steps/align_fmllr.sh --nj $num_jobs --cmd "$train_cmd" \
    data/train data/lang exp/tri3b exp/tri3b_ali || exit 1;
fi

if [ $stage -le 12 ] && $decode_gmm; then
  utils/mkgraph.sh data/lang_test exp/tri3b exp/tri3b/graph
  steps/decode_fmllr.sh --nj $num_decode_jobs --cmd \
    "$decode_cmd" exp/tri3b/graph data/dev exp/tri3b/decode
fi

if [ $stage -le 13 ]; then
  echo "$0: Training a regular chain model using the e2e alignments..."
  local/chain/tuning/run_tdnn_1b.sh
fi

if [ $stage -le 14 ] && $run_rnnlm; then
  local/rnnlm/run_tdnn_lstm.sh
fi

echo "$0: training succeeded"
exit 0
