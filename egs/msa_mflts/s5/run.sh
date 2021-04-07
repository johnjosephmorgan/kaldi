#!/bin/bash 

. ./cmd.sh
. ./path.sh
. $KALDI_ROOT/tools/env.sh
stage=0

. ./utils/parse_options.sh

set -e
set -o pipefail
set u

train_audio_dir=/mnt/corpora/mflts/Modern\ Standard\ Arabic/Speech/primary\ data\ TRAINING\ ONLY
train_txt_dir=/mnt/corpora/mflts/Modern\ Standard\ Arabic/Speech/annotation/MSA\ Transcription\ TRAINING
test_audio_dir=/mnt/corpora/mflts/Modern\ Standard\ Arabic/Speech/primary\ data\ TEST\ ONLY
test_txt_dir=/mnt/corpora/mflts/Modern\ Standard\ Arabic/Speech/annotation/MSA\ Transcription\ TEST
tmpdir=data/local/tmp
mflts_tmpdir=$tmpdir/mflts
tmp_train_dir=$mflts_tmpdir/train
tmp_test_dir=$mflts_tmpdir/test
tmp_dict_dir=$mflts_tmpdir/dict
lex=/mnt/corpora/mflts/Modern\ Standard\ Arabic/Speech/annotation/MSA\ Lexicon/ARA_MSA_Lexicon_20110818_u8.txt
g2p_input_text_files="data/dev/text data/train/text"

if [ $stage -le 1 ]; then
  echo "$0: Getting a list of the  MFLTS  MSA training .wav files."
  mkdir -p $tmp_train_dir/lists
  find "$train_audio_dir" -type f -name "*.wav" > $tmp_train_dir/wav_files.txt
fi

if [ $stage -le 2 ]; then
  echo "$0: Getting a list of the   MFLTS MSA training transcript files."
  find "$train_txt_dir" -type f -name "*.tdf" > $tmp_train_dir/tdf_files.txt
fi

if [ $stage -le 3 ]; then
  echo "$0: Getting  a list of the MFLTS MSA  test .wav files."
  mkdir -p $tmp_test_dir
  find "$test_audio_dir" -type f -name "*.wav" > $tmp_test_dir/wav_files.txt
  echo "$0: Getting  MFLTS MSA test transcript files."
  find "$test_txt_dir" -type f -name "*.tdf" > $tmp_test_dir/tdf_files.txt
fi

if [ $stage -le 4 ]; then
  echo "$0: Preparing the MFLTS  MSA    training data."
  local/mflts/make_lists_train.pl || exit 1;
  utils/fix_data_dir.sh $tmp_train_dir/lists || exit 1;
fi

if [ $stage -le 5 ]; then
  echo "$0: Preparing the MFLTS MSA  Test data."
  mkdir -p $tmp_test_dir/lists
  local/mflts/make_lists_test.pl || exit 1;
  utils/fix_data_dir.sh $tmp_test_dir/lists || exit 1;
fi

if [ $stage -le 6 ]; then
  echo "$0: Putting    data under the   data/train directory."
  mkdir -p data/{test,train}
  for x in wav.scp utt2spk text segments; do
    cat $tmp_train_dir/lists/$x | tr "	" " " > data/train/$x
  done
  utils/utt2spk_to_spk2utt.pl data/train/utt2spk > data/train/spk2utt || exit 1;
  utils/fix_data_dir.sh data/train || exit 1;
fi

if [ $stage -le 7 ]; then
  echo "$0: Putting    data under the   data/test directory."
  for x in wav.scp utt2spk text segments; do
    cat $tmp_test_dir/lists/$x | tr "	" " " > data/test/$x
  done
  utils/utt2spk_to_spk2utt.pl data/test/utt2spk > data/test/spk2utt || exit 1;
  utils/fix_data_dir.sh data/test || exit 1;
  echo "$0: Consolidating MFLTS MSA  test data."
  mkdir -p data/test
  for x in wav.scp utt2spk text segments; do
    cat $tmp_test_dir/lists/$x > data/test/$x
  done
  utils/utt2spk_to_spk2utt.pl data/test/utt2spk > data/test/spk2utt
  utils/fix_data_dir.sh data/test
fi

if [ $stage -le 8 ]; then
  echo "$0: Preparing the lexicon."
  mkdir -p $tmp_dict_dir
  cut -f 1 "$lex" > $tmp_dict_dir/words.txt
  cut -f 4 "$lex" > $tmp_dict_dir/prons.txt
  local/mflts/map_phones.pl $tmp_dict_dir/prons.txt > $tmp_dict_dir/prons_mapped.txt
  paste $tmp_dict_dir/words.txt $tmp_dict_dir/prons_mapped.txt > $tmp_dict_dir/lex.txt
  local/prepare_dict.sh $tmp_dict_dir/lex.txt $tmp_dict_dir/init || exit 1;
fi

if [ $stage -le 9 ]; then
  echo "$0: Training a g2p model."
  local/g2p/train_g2p.sh $tmp_dict_dir/init \
    $tmp_dict_dir/g2p || exit 1;
fi

if [ $stage -le 10 ]; then
  echo "$0: Applying the g2p."
  local/g2p/apply_g2p.sh $tmp_dict_dir/g2p/model.fst \
    $tmp_dict_dir/work $tmp_dict_dir/init/lexicon.txt \
    $tmp_dict_dir/init/lexicon_with_tabs.txt $g2p_input_text_files || exit 1;
fi

if [ $stage -le 11    ]; then
  echo "$0: Delimiting fields with space instead of tabs."
  mkdir -p $tmp_dict_dir/final
  expand -t 1 $tmp_dict_dir/init/lexicon_with_tabs.txt > $tmp_dict_dir/final/lexicon.txt
fi

if [ $stage -le 12    ]; then
  echo "$0: Preparing expanded lexicon."
  local/prepare_dict.sh $tmp_dict_dir/final/lexicon.txt \
    data/local/dict || exit 1;
  echo "$0: Adding <UNK> to the lexicon."
  echo "<UNK> SPN" >> data/local/dict/lexicon.txt
fi

if [ $stage -le 13 ]; then
  echo "$0: Preparing the MFLTS lang directory."
  utils/prepare_lang.sh data/local/dict "<UNK>" \
    data/local/lang_tmp data/lang || exit 1;
fi

if [ $stage -le 14 ]; then
  echo "$0: Getting data for lm training."
  mkdir -p $tmpdir/lm
  echo "$0: Put the MFLTS training transcripts in the lm training set."
  cut -d " " -f 2- data/train/text >> $tmpdir/lm/train.txt
fi

if [ $stage -le 15 ]; then
  echo "$0: Preparing a 3-gram lm."
  local/prepare_lm.sh || exit 1;
fi

if [ $stage -le 16 ]; then
  echo "$0: Making G.fst."
  mkdir -p data/lang_test
  utils/format_lm.sh data/lang data/local/lm/tg.arpa.gz \
    data/local/dict/lexicon.txt data/lang_test || exit 1;
fi

if [ $stage -le 17 ]; then
  echo "$0: Creating ConstArpaLm format language model."
  utils/build_const_arpa_lm.sh data/local/lm/tg.arpa.gz \
    data/lang data/lang_test || exit 1;
fi

if [ $stage -le 18 ]; then
  for f in  test train; do
    echo "$0: extracting acoustic features for $f."
    utils/fix_data_dir.sh data/$f
    steps/make_mfcc.sh --cmd "$train_cmd" --nj 56 data/$f exp/make_mfcc/$f mfcc
    utils/fix_data_dir.sh data/$f
    steps/compute_cmvn_stats.sh data/$f exp/make_mfcc mfcc
    utils/fix_data_dir.sh data/$f
  done
fi

if [ $stage -le 19 ]; then
  echo "$0: monophone training"
  steps/train_mono.sh  --cmd "$train_cmd" --nj 4 data/train \
    data/lang exp/mono || exit 1;
fi

if [ $stage -le 20 ]; then
  echo "$0: Monophone evaluation."
  (
    echo "$0: Making decoding graph for monophones."
    utils/mkgraph.sh data/lang_test exp/mono exp/mono/graph || exit 1;

    for f in  test ; do
      echo "$0: Testing monophones on $f."
      nspk=$(wc -l < data/$f/spk2utt)
      steps/decode.sh  --cmd "$decode_cmd" --nj $nspk \
        exp/mono/graph data/$f \
        exp/mono/decode_${f} || exit 1;
    done
  ) &
fi

if [ $stage -le 21 ]; then
  echo "$0: aligning with monophones"
  steps/align_si.sh  --cmd "$train_cmd" --nj 24 data/train data/lang \
    exp/mono exp/mono_ali || exit 1;
fi

if [ $stage -le 22 ]; then
  echo "$0: Starting  triphone training in exp/tri1."
  steps/train_deltas.sh --cmd "$train_cmd" --boost-silence 1.25 \
    5500 50000 \
    data/train data/lang exp/mono_ali exp/tri1 || exit 1;
fi

if [ $stage -le 23 ]; then
  echo "$0: testing cd gmm hmm models"
  (
    echo "$0: Making decoding graphs for tri1."
    utils/mkgraph.sh data/lang_test exp/tri1 exp/tri1/graph || exit 1;

    for f in test; do
      echo "Decoding $f data with tri1 models."
      nspk=$(wc -l < data/$f/spk2utt)
      steps/decode.sh --cmd "$decode_cmd" --nj $nspk exp/tri1/graph data/$f \
        exp/tri1/decode_${f} || exit 1;
    done
  ) &
fi

if [ $stage -le 24 ]; then
  echo "$0: Aligning with triphones tri1."
  steps/align_si.sh  --cmd "$train_cmd" --nj 24 data/train data/lang \
    exp/tri1 exp/tri1_ali || exit 1;
fi

if [ $stage -le 25 ]; then
  echo "$0: Starting lda_mllt triphone training in exp/tri2b."
  steps/train_lda_mllt.sh --cmd "$train_cmd" \
    --splice-opts "--left-context=3 --right-context=3" \
    5500 90000 \
    data/train data/lang exp/tri1_ali exp/tri2b || exit 1;
fi

if [ $stage -le 26 ]; then
  (
    echo "$0: Making decoding FSTs for tri2b models."
    utils/mkgraph.sh data/lang_test exp/tri2b exp/tri2b/graph || exit 1;

    for f in test; do
      echo "$0: decoding $f with tri2b models."
      nspk=$(wc -l < data/$f/spk2utt)
      steps/decode.sh --cmd "$decode_cmd" --nj $nspk exp/tri2b/graph data/$f \
        exp/tri2b/decode_${f} || exit 1;
      done
  ) &
fi

if [ $stage -le 27 ]; then
  echo "$0: aligning with lda and mllt adapted triphones $tri2b."
  steps/align_si.sh  --nj 24 \
    --cmd "$train_cmd" \
    --use-graphs true data/train data/lang exp/tri2b \
    exp/tri2b_ali || exit 1;
fi

if [ $stage -le 28 ]; then
  echo "$0: Starting SAT triphone training in exp/tri3b."
  steps/train_sat.sh --cmd "$train_cmd" \
    5500 50000 \
    data/train data/lang exp/tri2b_ali exp/tri3b || exit 1;
fi

if [ $stage -le 29 ]; then
  (
    echo "$0: making decoding graph for SAT and tri3b models."
    utils/mkgraph.sh data/lang_test exp/tri3b exp/tri3b/graph || exit 1;

    for f in test; do
      echo "$0: Decoding $f with sat models."
      nspk=$(wc -l < data/$f/spk2utt)
      steps/decode_fmllr.sh --cmd "$decode_cmd" --nj $nspk \
        exp/tri3b/graph data/$f \
  	exp/tri3b/decode_${f} || exit 1;
    done
  ) &
fi

if [ $stage -le 30 ]; then
  echo "$0: Starting exp/tri3b_ali"
  steps/align_fmllr.sh --cmd "$train_cmd" --nj 24 data/train data/lang \
			 exp/tri3b exp/tri3b_ali || exit 1;
fi

if [ $stage -le 31 ]; then
  echo "$0: Training and testing chain models."
  local/chain/run_tdnn.sh || exit 1;
fi
