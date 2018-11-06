#!/bin/bash -x

. ./cmd.sh
. ./path.sh

stage=0

. ./utils/parse_options.sh

set -e
set -o pipefail
set u

datadir=/mnt/corpora/westpoint_russian
tmpdir=data/local/tmp/westpoint_russian

if [ $stage -le 1 ]; then
  # make the temporary working data directory
  mkdir -p data/local/tmp/westpoint_russian
  for fld in test train; do
  #get a list of the .raw waveform files
    local/get_raw_list_${fld}.sh $datadir
  done

  # get a file containing a map from filename to transcript
  local/get_train_transcripts.sh $datadir

	# convert the waveform files to .wav
	local/raw2wav_${fld}.pl

fi
exit
if [ $stage -le 2 ]; then
    # make a dictionary
    if [ -d data/local/dict ]; then
	rm -Rf data/local/dict
    fi

    mkdir -p data/local/dict

    local/prepare_dict.sh
fi

if [ $stage -le 3 ]; then
    # prepare the lang directory
    utils/prepare_lang.sh \
	data/local/dict \
	"<UNK>" \
	data/local/lang \
	data/lang   || exit 1;
fi

if [ $stage -le 4 ]; then
    for fld in test train; do
	# get acoustic model training and testing lists
	mkdir -p data/$fld

	for x in wav.scp utt2spk text; do
	    sort \
		$tmpdir/$fld/$x \
		> \
		data/$fld/$x
	done

	# spk2utt
	utils/utt2spk_to_spk2utt.pl \
	    data/$fld/utt2spk \
	    | \
	    sort \
		> \
		data/$fld/spk2utt
    utils/fix_data_dir.sh \
	data/$fld
    done
fi

if [ $stage -le 5 ]; then
    # prepare lm
    local/prepare_lm.sh

    mkdir -p data/local/lm

    if [ -e language_models/lm_threegram.arpa.gz ]; then
	gunzip language_models/lm_threegram.arpa.gz 
fi

    # find out of vocabulary words
    utils/find_arpa_oovs.pl \
	data/lang/words.txt \
	language_models/lm_threegram.arpa \
	> \
	data/lang/oovs_3g.txt || exit 1;

    # make an fst out of the lm
    arpa2fst \
	language_models/lm_threegram.arpa \
	> \
	data/lang/lm_3g.fst || exit 1;

    # remove out of vocabulary arcs
    fstprint 	\
	data/lang/lm_3g.fst \
	| \
	utils/remove_oovs.pl 	    \
	    data/lang/oovs_3g.txt \
	    > \
	    data/lang/lm_3g_no_oovs.txt

    # replace epsilon symbol with \#0
    utils/eps2disambig.pl \
	< \
	data/lang/lm_3g_no_oovs.txt \
	| \
	utils/s2eps.pl \
	    > \
	    data/lang/lm_3g_with_disambig_symbols_without_s.txt

    # binarize the fst
    fstcompile \
	--isymbols=data/lang/words.txt \
	--osymbols=data/lang/words.txt \
	--keep_isymbols=false \
	--keep_osymbols=false \
	data/lang/lm_3g_with_disambig_symbols_without_s.txt \
	data/lang/lm_3g_with_disambig_symbols_without_s.fst

    # make the G.fst
    fstarcsort \
	data/lang/lm_3g_with_disambig_symbols_without_s.fst \
	data/lang/G.fst

    if [ -e language_models/lm_threegram.arpa ]; then
	gzip language_models/lm_threegram.arpa
    fi
fi

if [ $stage -le 6 ]; then
# extract acoustic features
    # make the exp directory
    mkdir -p exp

    for fld in test train; do
	if [ -e data/train/cmvn.scp ]; then
	    rm \
		data/train/cmvn.scp
	fi

	steps/make_mfcc.sh \
	    --cmd run.pl \
	    --nj 4 \
	    data/$fld \
	    exp/make_mfcc/$fld \
	    mfcc || exit 1;

	utils/fix_data_dir.sh \
	    data/$fld || exit 1;

	steps/compute_cmvn_stats.sh \
	    data/$fld \
	    exp/make_mfcc\
	    mfcc || exit 1;

	utils/fix_data_dir.sh \
	    data/$fld || exit 1;
	done
fi

if [ $stage -le 7 ]; then
    echo "Starting  monophone training in exp/mono on" `date`
    steps/train_mono.sh \
	--nj 8 \
	--cmd run.pl \
	data/train \
	data/lang \
	exp/mono || exit 1;
fi

if [ $stage -le 8 ]; then
    # make the decoding graph
    utils/mkgraph.sh \
	data/lang \
	exp/mono \
	exp/mono/graph || exit 1;
fi

if [ $stage -le 9 ]; then
    (
	# test
	steps/decode.sh \
	    --nj 4  \
	    exp/mono/graph  \
	    data/test \
	    exp/mono/decode_test || exit 1;
    ) &
fi

if [ $stage -le 10 ]; then
    # align
    steps/align_si.sh \
	--nj 5 \
	--cmd run.pl \
	data/train \
	data/lang \
	exp/mono \
	exp/mono_ali || exit 1;
fi

if [ $stage -le 11 ]; then
    echo "Starting  triphone training in exp/tri1 on" `date`
    steps/train_deltas.sh \
	--cmd run.pl \
	--cluster-thresh 100 \
	1500 \
	25000 \
	data/train \
	data/lang \
	exp/mono_ali \
	exp/tri1 || exit 1;
fi

if [ $stage -le 12 ]; then
    # align with triphones
    steps/align_si.sh \
	--nj 5 \
	--cmd run.pl \
	data/train \
	data/lang \
	exp/tri1 \
	exp/tri1_ali
fi

if [ $stage -le 13 ]; then
    echo "Starting (lda_mllt) triphone training in exp/tri2b on" `date`
    steps/train_lda_mllt.sh \
	--splice-opts "--left-context=3 --right-context=3" \
	3100 \
	50000 \
	data/train \
	data/lang \
	exp/tri1_ali \
	exp/tri2b
fi

if [ $stage -le 14 ]; then
    # align with lda and mllt adapted triphones
    steps/align_si.sh \
	--use-graphs true \
	--nj 5 \
	--cmd run.pl \
	data/train \
	data/lang \
	exp/tri2b \
	exp/tri2b_ali
fi

if [ $stage -le 15 ]; then
    # make decoding graph for tri1
    utils/mkgraph.sh \
	data/lang  \
	exp/tri1 \
	exp/tri1/graph || exit 1;
fi

if [ $stage -le 16 ]; then
    (
	# decode test data with tri1 models
	steps/decode.sh \
	    --nj 3  \
	    exp/tri1/graph  \
	    data/test \
	    exp/tri1/decode_test || exit 1;
) &
fi

if [ $stage -le 17 ]; then
    #  make decoding fst for tri2b models
    utils/mkgraph.sh \
	data/lang  \
	exp/tri2b \
	exp/tri2b/graph || exit 1;
fi

if [ $stage -le 18 ]; then
    (
	# decode  test with tri2b models
	steps/decode.sh \
	    --nj 2  \
	    exp/tri2b/graph \
	    data/test \
	    exp/tri2b/decode_test || exit 1;
    ) &
fi
exit
if [ $stage -le 19 ]; then
    echo "Starting (SAT) triphone training in exp/tri3b on" `date`
    steps/train_sat.sh \
	--cmd run.pl \
	3100 \
	50000 \
	data/train \
	data/lang \
	exp/tri2b_ali \
	exp/tri3b
fi

if [ $stage -le 20 ]; then
    utils/mkgraph.sh \
	data/lang  \
	exp/tri3b \
	exp/tri3b/graph ||  exit 1;
fi

if [ $stage -le 21 ]; then
    (
	# decode test set with tri3b models
	steps/decode_fmllr.sh \
	    --nj 3 \
	    --cmd run.pl \
            exp/tri3b/graph \
	    data/test \
            exp/tri3b/decode_test
    ) &
fi
exit
if [ $stage -le 22 ]; then
    echo "Starting exp/tri3b_ali on" `date`
    steps/align_fmllr.sh \
	--nj 5 \
	--cmd run.pl \
	data/train \
	data/lang \
	exp/tri3b \
	exp/tri3b_ali
fi

if [ $stage -le 23 ]; then
    local/nnet3/run_ivector_common.sh
fi

if [ $stage -le 24 ]; then
    local/chain/run_tdnn.sh
fi
john@A-TEAM19054:~/russian$ 
