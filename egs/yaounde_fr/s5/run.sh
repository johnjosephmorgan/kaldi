#!/bin/bash 

# Uses the cmusphinx French lexicon.

. ./cmd.sh
. ./path.sh
stage=0

. ./utils/parse_options.sh

set -e
set -o pipefail
set u

# Do not change tmpdir, other scripts under local depend on it
tmpdir=data/local/tmp

# Some of the speech corpora are on openslr.org
# location of corpora
yaounde_corpus=/mnt/disk01/yaounde_data
# We use the cmusphinx lexicon.
lex='https://sourceforge.net/projects/cmusphinx/files/Acoustic and Language Models/French/fr.dict/download'

# We train a large lm on subtitles.
subs_src="http://opus.nlpl.eu/download.php?f=OpenSubtitles2018/mono/OpenSubtitles2018.fr.gz"

if [ $stage -le 1 ]; then
  # Downloads archive to this script's directory
  #local/yaounde_fr_download.sh $speech

  local/cmusphinx_fr_lexicon_download.sh $lex

  local/subs/download.sh $subs_src
fi

# preparation stages will store files under data/
# Delete the entire data directory when restarting.
if [ $stage -le 2 ]; then
  local/prepare_data.sh $yaounde_corpus
fi

if [ $stage -le 3 ]; then
  mkdir -p $tmpdir/dict

  local/prepare_dict.sh ./fr.dict
fi

if [ $stage -le 4 ]; then
  # prepare the lang directory
  utils/prepare_lang.sh data/local/dict_nosp "<UNK>" data/local/lang_tmp_nosp data/lang_nosp
fi

if [ $stage -le 5 ]; then
  echo "Preparing the subs data for lm training."
  local/subs/prepare_data.pl 
fi

if [ $stage -le 6 ]; then
  echo "lm training."

  mkdir -p $tmpdir/yaounde/lm

  cut -f 2- data/train/text > $tmpdir/yaounde/lm/train.txt

  local/prepare_small_lm.sh  $tmpdir/yaounde/lm/train.txt

  local/prepare_medium_lm.sh  $tmpdir/subs/lm/in_vocabulary.txt

  local/prepare_large_lm.sh  $tmpdir/subs/lm/in_vocabulary.txt
fi

if [ $stage -le 7 ]; then
  echo "Making grammar fst."
  for l in tgsmall tgmed; do
    mkdir -p data/lang_nosp_test_${l}
    utils/format_lm.sh \
      data/lang_nosp data/local/lm/$l.arpa.gz data/local/dict_nosp/lexicon.txt \
      data/lang_nosp_test_${l}
  done
    # Create ConstArpaLm format language model for full 3-gram and 4-gram LMs
  utils/build_const_arpa_lm.sh data/local/lm/tglarge.arpa.gz \
    data/lang_nosp data/lang_nosp_test_tglarge
fi

if [ $stage -le 8 ]; then
  # extract acoustic features
  for f in dev train test; do
    steps/make_mfcc.sh --cmd "$train_cmd" --nj 9 data/$f exp/make_mfcc/$f mfcc
    utils/fix_data_dir.sh data/$f
    steps/compute_cmvn_stats.sh data/$f exp/make_mfcc mfcc
    utils/fix_data_dir.sh data/$f
  done

  # Get the shortest 500 utterances first because those are more likely
  # to have accurate alignments.
  utils/subset_data_dir.sh --shortest data/train 500 data/train_500short

fi

if [ $stage -le 9 ]; then
  echo "$0: monophone training"
  steps/train_mono.sh  --cmd "$train_cmd" --nj 10 data/train_500short \
    data/lang_nosp exp/mono
fi

if [ $stage -le 10 ]; then
  # monophone evaluation
  (
    # make decoding graph for monophones
      utils/mkgraph.sh data/lang_nosp_test_tgsmall exp/mono \
        exp/mono/graph_nosp_tgsmall

    # test monophones
    for x in dev test; do
      nspk=$(wc -l < data/$x/spk2utt)
      steps/decode.sh  --cmd "$decode_cmd" --nj $nspk \
        exp/mono/graph_nosp_tgsmall data/$x exp/mono/decode_nosp_tgsmall_${x}
    done
  ) &
fi

if [ $stage -le 11 ]; then
  # align with monophones
    steps/align_si.sh  --cmd "$train_cmd" --nj 10 data/train data/lang_nosp \
      exp/mono exp/mono_ali
fi

if [ $stage -le 12 ]; then
  echo "$0: Starting  triphone training in exp/tri1"
  steps/train_deltas.sh \
    --cmd "$train_cmd" \
    --boost-silence 1.25 \
    3000 12000 \
    data/train data/lang_nosp exp/mono_ali exp/tri1
fi

wait

if [ $stage -le 13 ]; then
  # test cd gmm hmm models
  # make decoding graphs for tri1
  (
      utils/mkgraph.sh data/lang_nosp_test_tgsmall exp/tri1 \
        exp/tri1/graph_nosp_tgsmall

    # decode test data with tri1 models
    for x in dev test; do
      nspk=$(wc -l < data/$x/spk2utt)
      steps/decode.sh --cmd "$decode_cmd" --nj $nspk exp/tri1/graph_nosp_tgsmall \
        data/$x exp/tri1/decode_nosp_tgsmall_${x}

      steps/lmrescore.sh --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tgmed} \
        data/$x exp/tri1/decode_nosp_{tgsmall,tgmed}_$x

      steps/lmrescore_const_arpa.sh \
        --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tglarge} \
        data/$x exp/tri1/decode_nosp_{tgsmall,tglarge}_$x
    done
  ) &
fi

if [ $stage -le 14 ]; then
  # align with triphones
    steps/align_si.sh  --cmd "$train_cmd" --nj 10 data/train data/lang_nosp \
      exp/tri1 exp/tri1_ali
fi
exit
if [ $stage -le 15 ]; then
  echo "$0: Starting (lda_mllt) triphone training in exp/tri2b"
  steps/train_lda_mllt.sh \
    --cmd "$train_cmd" \
    --splice-opts "--left-context=3 --right-context=3" 4000 20000 \
    data/train data/lang_nosp exp/tri1_ali exp/tri2b
fi

wait

if [ $stage -le 16 ]; then
  (
    #  make decoding FSTs for tri2b models
      utils/mkgraph.sh data/lang_nosp_test_tgsmall exp/tri2b \
        exp/tri2b/graph_nosp_tgsmall

    # decode  test with tri2b models
    for x in dev test; do
      nspk=$(wc -l < data/$x/spk2utt)
      steps/decode.sh --cmd "$decode_cmd" --nj $nspk \
        exp/tri2b/graph_nosp_tgsmall data/$x exp/tri2b/decode_nosp_tgsmall_${x}

      steps/lmrescore.sh --cmd "$decode_cmd" \
        data/lang_nosp_test_{tgsmall,tgmed} data/$x \
        exp/tri2b/decode_nosp_{tgsmall,tgmed}_$x

      steps/lmrescore_const_arpa.sh \
        --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tglarge} \
        data/$x exp/tri2b/decode_nosp_{tgsmall,tglarge}_$x
    done
  ) &
fi

if [ $stage -le 17 ]; then
  # align with lda and mllt adapted triphones
    steps/align_si.sh \
      --cmd "$train_cmd" \
      --use-graphs true data/train data/lang_nosp exp/tri2b exp/tri2b_ali
fi

if [ $stage -le 18 ]; then
  echo "$0: Starting (SAT) triphone training in exp/tri3b"
  steps/train_sat.sh --cmd "$train_cmd" 4000 20000 data/train data/lang_nosp \
    exp/tri2b_ali exp/tri3b
fi

if [ $stage -le 19 ]; then
  (
    # make decoding graphs for SAT models
      utils/mkgraph.sh data/lang_test_nosp_tgsmall exp/tri3b \
        exp/tri3b/graph_nosp_tgsmall

    # decode test sets with tri3b models
    for x in dev test; do
      nspk=$(wc -l < data/$x/spk2utt)
      steps/decode_fmllr.sh --cmd "$decode_cmd" --nj $nspk \
        exp/tri3b/graph_nosp_tgsmall data/$x exp/tri3b/decode_nosp_tgsmall_${x}

      steps/lmrescore.sh --cmd "$decode_cmd" \
 data/lang_nosp_test_{tgsmall,tgmed} data/$x exp/tri3b/decode_nosp_{tgsmall,tgmed}_$x

      steps/lmrescore_const_arpa.sh \
        --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tglarge} \
        data/$x exp/tri3b/decode_nosp_{tgsmall,tglarge}_$x
    done
  ) &
fi

if [ $stage -le 20 ]; then
  # align with tri3b models
  echo "$0: Starting exp/tri3b_ali"
  steps/align_fmllr.sh --cmd "$train_cmd" --nj 10 data/train data/lang_nosp \
    exp/tri3b exp/tri3b_ali
fi

# Now we compute the pronunciation and silence probabilities from training data,
# and re-create the lang directory.
if [ $stage -le 21 ]; then
  steps/get_prons.sh --cmd "$train_cmd" \
    data/train data/lang_nosp exp/tri3b

  utils/dict_dir_add_pronprobs.sh --max-normalize true \
    data/local/dict_nosp \
    exp/tri3b/pron_counts_nowb.txt exp/tri3b/sil_counts_nowb.txt \
    exp/tri3b/pron_bigram_counts_nowb.txt data/local/dict

  utils/prepare_lang.sh data/local/dict \
    "<UNK>" data/local/lang_tmp data/lang

  local/format_lms.sh --src-dir data/lang data/local/lm

  utils/build_const_arpa_lm.sh \
    data/local/lm/lm_tglarge.arpa.gz data/lang data/lang_test_tglarge

  steps/align_fmllr.sh --nj 5 --cmd "$train_cmd" \
    data/train data/lang exp/tri3b exp/tri3b_ali_train
fi

if [ $stage -le 22 ]; then
  # Test the tri3b system with the silprobs and pron-probs.

  # decode using the tri3b model
  utils/mkgraph.sh data/lang_test_tgsmall \
                   exp/tri3b exp/tri3b/graph_tgsmall
  for x in dev test; do
    steps/decode_fmllr.sh --nj 10 --cmd "$decode_cmd" \
      exp/tri3b/graph_tgsmall data/$x \
      exp/tri3b/decode_tgsmall_$x

    steps/lmrescore.sh --cmd "$decode_cmd" data/lang_test_{tgsmall,tgmed} \
      data/$x exp/tri3b/decode_{tgsmall,tgmed}_$x


    steps/lmrescore_const_arpa.sh \
      --cmd "$decode_cmd" data/lang_test_{tgsmall,tglarge} \
      data/$x exp/tri3b/decode_{tgsmall,tglarge}_$x
  done
fi

if [ $stage -le 23 ]; then
  # train and test chain models
  local/chain/run_tdnn.sh
fi
