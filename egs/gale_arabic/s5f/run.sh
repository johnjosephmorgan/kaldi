#!/bin/bash -e

# Small system
num_jobs=60
num_decode_jobs=60
decode_gmm=false
stage=0
overwrite=true

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
    utils/subset_data_dir.sh data/train 5000 data/train.5K || exit 1;
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
    data/train.5K \
    data/lang \
    exp/mono || exit 1;
fi

if [ $stage -le 8 ]; then
  echo "$0: Aligning data using monophone system"
  steps/align_si.sh \
    --cmd "$train_cmd" \
    --nj $num_jobs \
    data/train.10K \
    data/lang \
    exp/mono \
    exp/mono_ali || exit 1;

  echo "$0: training triphone system with delta features"
  steps/train_deltas.sh \
    --cmd "$train_cmd" \
    2500 30000 \
    data/train.10K \
    data/lang \
    exp/mono_ali \
    exp/tri1 || exit 1;
fi

if [ $stage -le 9 ]; then
  echo "$0: Aligning data and retraining and realigning with lda_mllt"
  steps/align_si.sh \
    --cmd "$train_cmd" \
    --nj $num_jobs \
    data/train.20K \
    data/lang \
    exp/tri1 \
    exp/tri1_ali || exit 1;

  steps/train_lda_mllt.sh \
    --cmd "$train_cmd" \
    3000 40000 \
    data/train.20K \
    data/lang \
    exp/tri1_ali \
    exp/tri2b || exit 1;
fi

if [ $stage -le 10 ]; then
  echo "$0: Aligning data and retraining and realigning with sat_basis"
  steps/align_si.sh \
    --cmd "$train_cmd" \
    --nj $num_jobs \
    data/train.30K \
    data/lang \
    exp/tri2b \
    exp/tri2b_ali || exit 1;

  steps/train_sat_basis.sh \
    --cmd "$train_cmd" \
    4000 80000 \
    data/train.30K \
    data/lang \
    exp/tri2b_ali \
    exp/tri3b || exit 1;

  steps/align_fmllr.sh \
    --cmd "$train_cmd" \
    --nj $num_jobs \
    data/train.30K \
    data/lang \
    exp/tri3b \
    exp/tri3b_ali || exit 1;
fi

if [ $stage -le 11 ]; then
  echo "$0: Training a regular chain model using the e2e alignments..."
  local/chain/tuning/run_tdnn_1c.sh
fi

echo "$0: training succeeded"
exit 0
