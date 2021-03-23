#!/bin/bash 

set -euo pipefail
. ./cmd.sh
. ./path.sh

stage=-4

. ./utils/parse_options.sh

# Set the locations of the GlobalPhone corpus and language models
gp_corpus=/mnt/corpora/Globalphone/MSA_ASR001_WAV
gp_lexicon=/mnt/corpora/Globalphone/GlobalPhoneLexicons/Arabic/Arabic-GPDict.txt
tmpdir=data/local/tmp/gp/arabic
tmp_eval_dir=data/local/tmp/transtac_iraqi_arabic/eval

# global phone data prep
if [ $stage -le 0 ]; then
    mkdir -p $tmpdir/lists

    # get list of globalphone .wav files
    find $gp_corpus/adc -type f -name "*.wav" | sort > $tmpdir/lists/wav.txt

    # get  list of Globalphone trl files 
    find $gp_corpus/trl -type f -name "*.trl" | sort > $tmpdir/lists/trl.txt

    for fld in dev eval train; do
	mkdir -p $tmpdir/$fld/lists

	grep -f conf/${fld}_spk.list  $tmpdir/lists/wav.txt  > \
	     $tmpdir/$fld/lists/wav.txt

	grep -f conf/${fld}_spk.list  $tmpdir/lists/trl.txt  > \
	     $tmpdir/$fld/lists/trl.txt

	local/get_prompts.pl $fld

	# make training lists
	local/make_lists.pl $fld

	utils/fix_data_dir.sh $tmpdir/$fld/lists

	# consolidate  data lists
	mkdir -p data/$fld
	for x in wav.scp text utt2spk; do
	    cat $tmpdir/$fld/lists/$x | sort >> data/$fld/$x
	done

	utils/utt2spk_to_spk2utt.pl data/$fld/utt2spk | sort > data/$fld/spk2utt

	utils/fix_data_dir.sh data/$fld
    done
fi

if [ $stage -le 1 ]; then
    mkdir -p $tmpdir/dict

    local/gp_norm_dict_AR.pl $gp_lexicon | sort -u > $tmpdir/dict/lexicon.txt

    local/prepare_dict.sh
fi

if [ $stage -le 2 ]; then
    # prepare lang directory
    utils/prepare_lang.sh \
	--position-dependent-phones false \
	data/local/dict \
	"<UNK>" \
	data/local/lang_tmp \
	data/lang
fi

if [ $stage -le 3 ]; then
    # prepare the lm
    mkdir -p data/local/lm

    local/prepare_lm.sh

    utils/format_lm.sh \
	data/lang \
	data/local/lm/threegram.arpa.gz \
	data/local/dict/lexicon.txt \
	data/lang_test
fi

if [ $stage -le 4 ]; then
    # Create ConstArpaLm format language model for full 3-gram and 4-gram LMs
    utils/build_const_arpa_lm.sh \
	data/local/lm/threegram.arpa.gz \
	data/lang \
	data/lang_test
fi

if [ $stage -le 5 ]; then
    # extract acoustic features
    mkdir -p exp

    if [ -e data/train/cmvn.scp ]; then
	rm data/train/cmvn.scp
    fi

    for fld in dev eval train ; do
	steps/make_mfcc.sh \
	    --cmd run.pl \
	    --nj 4 \
	    data/$fld \
	    exp/make_mfcc/$fld \
	    mfcc

	utils/fix_data_dir.sh data/$fld

	steps/compute_cmvn_stats.sh \
	    data/$fld \
	    exp/make_mfcc/$fld \
	    mfcc

	utils/fix_data_dir.sh data/$fld
    done
fi

if [ $stage -le 6 ]; then
    echo "Starting  monophone training in exp/mono on" `date`
    steps/train_mono.sh --nj 8 --cmd run.pl data/train data/lang exp/mono
fi

if [ $stage -le 7 ]; then
    # align with monophones
    steps/align_si.sh \
	--nj 5 --cmd run.pl data/train data/lang exp/mono exp/mono_ali
fi

if [ $stage -le 8 ]; then
  mkdir -p exp/mono/graph
  (
    utils/mkgraph.sh data/lang_test exp/mono exp/mono/graph

    for f in dev eval ; do
      steps/decode.sh --nj 5 --cmd "$decode_cmd" exp/mono/graph data/$f \
        exp/mono/decode_$f
    done
  ) &
fi

if [ $stage -le 9 ]; then
    echo "Starting  triphone training in exp/tri1 on" `date`
    steps/train_deltas.sh \
	--cluster-thresh 100 --cmd run.pl 500 5000 data/train data/lang \
	exp/mono_ali exp/tri1
fi

if [ $stage -le 10 ]; then
    # align with triphones
    steps/align_si.sh \
	--nj 5 \
	--cmd run.pl \
	data/train \
	data/lang \
	exp/tri1 \
	exp/tri1_ali
fi

if [ $stage -le 11 ]; then
  mkdir -p exp/tri1/graph
  (
    utils/mkgraph.sh data/lang_test exp/tri1 exp/tri1/graph

    for f in dev eval; do
      steps/decode.sh --nj 5 --cmd run.pl exp/tri1/graph data/$f \
        exp/tri1/decode_$f
    done
  ) &
fi

if [ $stage -le 12 ]; then
    echo "$0: Starting (lda_mllt) triphone training in exp/tri2b on" `date`
    steps/train_lda_mllt.sh \
	--splice-opts "--left-context=3 --right-context=3" \
	1600 \
	20000 \
	data/train \
	data/lang \
	exp/tri1_ali \
	exp/tri2b
fi

if [ $stage -le 13 ]; then
  echo "$0: Aligning with lda and mllt adapted triphones."
  steps/align_si.sh --use-graphs true --nj 5 --cmd run.pl data/train data/lang \
    exp/tri2b exp/tri2b_ali || exit 1;
fi

if [ $stage -le 14 ]; then
  echo "$0: Decoding tri2b."
  mkdir -p exp/tri2b/graph

  (
    utils/mkgraph.sh data/lang_test exp/tri2b exp/tri2b/graph || exit 1;

    for fld in dev eval; do
      steps/decode.sh --nj 5 --cmd "$decode_cmd" exp/tri2b/graph data/$fld \
        exp/tri2b/decode_${fld} || exit 1;
	done
  ) &
fi

if [ $stage -le 15 ]; then
  echo "$0: Starting (SAT) triphone training in exp/tri3b on" `date`
  steps/train_sat.sh --cmd run.pl \
    1700 40000 \
    data/train data/lang exp/tri2b_ali exp/tri3b || exit 1;
fi

if [ $stage -le 16 ]; then
  echo "$0: Decode tri3b."
  (
    utils/mkgraph.sh data/lang_test exp/tri3b exp/tri3b/graph || exit 1;

    for fld in dev eval; do
      steps/decode_fmllr.sh --nj 5 --cmd "$decode_cmd" exp/tri3b/graph \
        data/$fld exp/tri3b/decode_${fld} || exit 1;
    done
  ) &
fi

if [ $stage -le 17 ]; then
    echo "$0: Starting exp/tri3b_ali on" `date`
  steps/align_fmllr.sh --nj 5 --cmd run.pl data/train data/lang exp/tri3b \
    exp/tri3b_ali || exit 1;
fi

if [ $stage -le 18 ]; then
  echo "$0: Train and test chain models."
  local/chain/run_tdnn.sh
fi
