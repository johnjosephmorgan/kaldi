#!/bin/bash 

. ./cmd.sh
. ./path.sh
stage=0

. ./utils/parse_options.sh

set -e
set -o pipefail
set u

datadir=/mnt/disk01/westpoint_russian
tmpdir=data/local/tmp
lex='https://sourceforge.net/projects/cmusphinx/files/Acoustic and Language Models/Russian/cmusphinx-ru-5.2.tar.gz'
lexdir=cmusphinx-ru-5.2
subs_src="http://opus.nlpl.eu/download.php?f=OpenSubtitles2018/mono/OpenSubtitles2018.ru.gz"

if [ $stage -le 1 ]; then
  local/subs/download.sh $subs_src

  local/cmusphinx_download.sh $lex
fi

if [ $stage -le 2 ]; then
  local/prepare_data.sh $datadir
fi

if [ $stage -le 3 ]; then
  local/prepare_dict.sh $lexdir/ru.dic data/local/dict
  echo "<UNK> SPN" >> data/local/dict/lexicon.txt
fi

if [ $stage -le 4 ]; then
  utils/prepare_lang.sh data/local/dict "<UNK>" data/local/lang_tmp data/lang
fi

if [ $stage -le 5 ]; then
  echo "Small lm training."
  mkdir -p $tmpdir/ru/lm
  cut -d " " -f 2- data/train/text > $tmpdir/ru/lm/train.txt
  local/prepare_small_lm.sh  $tmpdir/ru/lm/train.txt
  echo "Making small G.fst."
  mkdir -p data/lang_test_tgsmall
  utils/format_lm.sh data/lang data/local/lm/tgsmall.arpa.gz \
    data/local/dict/lexicon.txt data/lang_test_tgsmall
fi

if [ $stage -le 6 ]; then
  echo "Preparing the subs data for larger lm training."
  # Subs prep depends on previous steps. 
  local/subs/prepare_data.pl 
fi

if [ $stage -le 7 ]; then
  local/prepare_medium_lm.sh  $tmpdir/subs/lm/in_vocabulary.txt
fi

if [ $stage -le 8 ]; then
  local/prepare_large_lm.sh  $tmpdir/subs/lm/in_vocabulary.txt
fi

if [ $stage -le 9 ]; then
  echo "Prepare medium size lang directory."
  mkdir -p data/lang_test_tgmed
  utils/format_lm.sh data/lang data/local/lm/tgmed.arpa.gz \
    data/local/dict/lexicon.txt data/lang_test_tgmed
fi

if [ $stage -le 10 ]; then
  echo "$0: Creating ConstArpaLm format language model for full 3-gram and 4-gram LMs"
  utils/build_const_arpa_lm.sh data/local/lm/tglarge.arpa.gz \
    data/lang data/lang_test_tglarge
fi

if [ $stage -le 11 ]; then
  # extract acoustic features
  for f in train test; do
    steps/make_mfcc.sh --cmd "$train_cmd" --nj 9 data/$f exp/make_mfcc/$f mfcc
    utils/fix_data_dir.sh data/$f
    steps/compute_cmvn_stats.sh data/$f exp/make_mfcc mfcc
    utils/fix_data_dir.sh data/$f
  done
fi
exit
if [ $stage -le 12 ]; then
  # Get the shortest 500 utterances first because those are more likely
  # to have accurate alignments.
  utils/subset_data_dir.sh --shortest data/train 500 data/train_500short

  echo "$0: monophone training"
  steps/train_mono.sh  --cmd "$train_cmd" --nj 10 data/train_500short \
    data/lang exp/mono
  echo "monophone evaluation"
  (
    # make decoding graph for monophones
    utils/mkgraph.sh data/lang_test_tgsmall exp/mono \
      exp/mono/graph_tgsmall

    # test monophones
    for x in  test; do
      nspk=$(wc -l < data/$x/spk2utt)
      steps/decode.sh  --cmd "$decode_cmd" --nj $nspk \
        exp/mono/graph_tgsmall data/$x exp/mono/decode_tgsmall_${x}
    done
  ) &
      echo "monophone evaluation with tgmed"
  (
    # make decoding graph for monophones
    utils/mkgraph.sh data/lang_test_tgmed exp/mono \
      exp/mono/graph_tgmed

    # test monophones
    for x in test; do
      nspk=$(wc -l < data/$x/spk2utt)
      steps/decode.sh  --cmd "$decode_cmd" --nj $nspk \
        exp/mono/graph_tgmed data/$x exp/mono/decode_tgmed_${x}
    done
  ) &
  echo "$0: aligning with monophones"
  steps/align_si.sh  --cmd "$train_cmd" --nj 10 data/train data/lang \
    exp/mono exp/mono_ali
fi

if [ $stage -le 13 ]; then
  echo "$0: Starting  triphone training in exp/tri1"
  steps/train_deltas.sh \
    --cmd "$train_cmd" \
    --boost-silence 1.25 \
    3000 12000 \
    data/train data/lang exp/mono_ali exp/tri1
fi

wait

if [ $stage -le 14 ]; then
  echo "$0: testing cd gmm hmm models"
  (
    # make decoding graphs for tri1
    utils/mkgraph.sh data/lang_test_tgsmall exp/tri1 \
      exp/tri1/graph_tgsmall

    echo "Decoding test data with tri1 an tgsmall dmodels."
    for x in test; do
      nspk=$(wc -l < data/$x/spk2utt)
      steps/decode.sh --cmd "$decode_cmd" --nj $nspk exp/tri1/graph_tgsmall \
        data/$x exp/tri1/decode_tgsmall_${x}
      echo "$0: testing with cd gmm hmm tgmed and tglarge models"
      # make decoding graphs for tri1
      utils/mkgraph.sh data/lang_test_tgmed exp/tri1 \
        exp/tri1/graph_tgmed

      echo "Decoding test data with tri1 tgmed an tglarge dmodels."
      nspk=$(wc -l < data/$x/spk2utt)
      steps/decode.sh --cmd "$decode_cmd" --nj $nspk exp/tri1/graph_tgmed \
        data/$x exp/tri1/decode_tgmed_${x}

      steps/lmrescore.sh --cmd "$decode_cmd" data/lang_test_{tgsmall,tgmed} \
        data/$x exp/tri1/decode_{tgsmall,tgmed}_$x

      steps/lmrescore_const_arpa.sh \
        --cmd "$decode_cmd" data/lang_test_{tgsmall,tglarge} \
        data/$x exp/tri1/decode_{tgsmall,tglarge}_$x
    done
  ) &
fi

if [ $stage -le 15 ]; then
  # align with triphones
  steps/align_si.sh  --cmd "$train_cmd" --nj 10 data/train data/lang \
    exp/tri1 exp/tri1_ali
fi

if [ $stage -le 16 ]; then
  echo "$0: Starting (lda_mllt) triphone training in exp/tri2b"
  steps/train_lda_mllt.sh \
    --cmd "$train_cmd" --splice-opts "--left-context=3 --right-context=3" \
    3500 16000 \
    data/train data/lang exp/tri1_ali exp/tri2b
fi

wait

if [ $stage -le 17 ]; then
  (
    echo "$0: Making decoding FSTs for tri2b models."
    utils/mkgraph.sh data/lang_test_tgsmall exp/tri2b \
      exp/tri2b/graph_tgsmall
    # decode  test with tri2b models
    for x in test; do
      nspk=$(wc -l < data/$x/spk2utt)
      steps/decode.sh --cmd "$decode_cmd" --nj $nspk \
        exp/tri2b/graph_tgsmall data/$x exp/tri2b/decode_tgsmall_${x}

      steps/lmrescore.sh --cmd "$decode_cmd" \
        data/lang_test_{tgsmall,tgmed} data/$x \
        exp/tri2b/decode_{tgsmall,tgmed}_$x

      steps/lmrescore_const_arpa.sh \
        --cmd "$decode_cmd" data/lang_test_{tgsmall,tglarge} \
        data/$x exp/tri2b/decode_{tgsmall,tglarge}_$x
    done
  )&
fi

if [ $stage -le 18 ]; then
  echo "$0: aligning with lda and mllt adapted triphones"
  steps/align_si.sh  --nj 10 \
    --cmd "$train_cmd" \
    --use-graphs true data/train data/lang exp/tri2b exp/tri2b_ali
fi

if [ $stage -le 19 ]; then
  echo "$0: Starting (SAT) triphone training in exp/tri3b"
  steps/train_sat.sh --cmd "$train_cmd" \
    4000 20000 \
    data/train data/lang exp/tri2b_ali exp/tri3b
fi

wait

if [ $stage -le 20 ]; then
  (
    echo "$0: making decoding graph for SAT models."
    utils/mkgraph.sh data/lang_test_tgsmall exp/tri3b \
      exp/tri3b/graph_tgsmall
    for x in  test; do
      echo "Decoding $x with sat and tgsmall models."
      nspk=$(wc -l < data/$x/spk2utt)
      steps/decode_fmllr.sh --cmd "$decode_cmd" --nj $nspk \
        exp/tri3b/graph_tgsmall data/$x \
        exp/tri3b/decode_tgsmall_${x}

      steps/lmrescore.sh --cmd "$decode_cmd" \
        data/lang_test_{tgsmall,tgmed} data/$x \
        exp/tri3b/decode_{tgsmall,tgmed}_$x
      steps/lmrescore_const_arpa.sh \
        --cmd "$decode_cmd" data/lang_test_{tgsmall,tglarge} \
        data/$x exp/tri3b/decode_nosp_{expanded_tgsmall,tglarge}_$x
    done
  )&
fi

if [ $stage -le 21 ]; then
  echo "$0: Starting exp/tri3b_ali"
  steps/align_fmllr.sh --cmd "$train_cmd" --nj 10 data/train data/lang \
    exp/tri3b exp/tri3b_ali
fi

if [ $stage -le 22 ]; then
  echo "$0: Testing the tri3b system with the silprobs and pron-probs."
  # decode using the tri3b and tgsmall model
  (
    utils/mkgraph.sh data/lang_test_tgsmall \
      exp/tri3b exp/tri3b/graph_tgsmall
    for x in test; do
      steps/decode_fmllr.sh --nj 10 --cmd "$decode_cmd" \
        exp/tri3b/graph_tgsmall data/$x \
        exp/tri3b/decode_tgsmall_$x

      steps/lmrescore.sh --cmd "$decode_cmd" data/lang_test_{tgsmall,tgmed} \
        data/$x exp/tri3b/decode_{tgsmall,tgmed}_$x
      steps/lmrescore_const_arpa.sh \
        --cmd "$decode_cmd" data/lang_test_{tgsmall,tglarge} \
        data/$x exp/tri3b/decode_{tgsmall,tglarge}_$x
    done
  )&
fi

if [ $stage -le 23 ]; then
  # train and test chain models
  local/chain/run_tdnn.sh
fi
