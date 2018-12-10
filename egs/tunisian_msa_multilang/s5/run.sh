#!/bin/bash
. ./cmd.sh
set -euo pipefail

# Begin Configuration variables settings
cmd=run.pl
stage=0
# Do not change tmpdir, other scripts under local depend on it
tmpdir=data/local/tmp
# variables to train the Tunisian MSA system
# The speech corpus is on openslr.org
speech="http://www.openslr.org/resources/46/Tunisian_MSA.tar.gz"
# We use the QCRI lexicon.
lex="http://alt.qcri.org/resources/speech/dictionary/ar-ar_lexicon_2014-03-17.txt.bz2"
g2p=0
# We train the lm on subtitles.
subs_src="http://opus.nlpl.eu/download.php?f=OpenSubtitles2018/mono/OpenSubtitles2018.ar.gz"
# Variables for mini librispeech
data=data_librispeech
data_url=www.openslr.org/resources/31
lm_url=www.openslr.org/resources/11
# Variables for mtl training
langs=(  librispeech Tunisian_MSA_CTELLONE );  # input languages
dir=exp/multi_librispeech_Tunisian_MSA;  # working directory
# directory for consolidated data preparation
multi_data_dir=data/multi_librispeech_Tunisian_MSA_CTELLONE;
decode_langs=( Tunisian_MSA_CTELLONE );   # test data language
lang2weight="0.2,0.8";  # weighting of input languages
lang_weights=(0.2 0.8 );
left_context=19;  # context frames
right_context=14;
samples=300000;  # samples per iteration 
num_langs=${#langs[@]};
num_weights=${#lang_weights[@]};
megs_dir=$dir/egs
dropout_schedule='0,0@0.20,0.5@0.50,0'
# End of Configuration variables settings

. ./path.sh
. ./cmd.sh
. ./utils/parse_options.sh

if [ $stage -le 1 ]; then
  # Downloads archive to this script's directory
  local/tamsa/download.sh $speech

  local/qcri_lexicon_download.sh $lex

  local/subs_download.sh $subs_src
fi

# preparation stages will store files under data/
# Delete the entire data directory when restarting.
if [ $stage -le 2 ]; then
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
  # Get the shortest 500 utterances first because those are more likely
  # to have accurate alignments.
  utils/subset_data_dir.sh --shortest data/tamsa/train 500 data/tamsa/train_500short
fi

if [ $stage -le 8 ]; then
  echo "$0: monophone training"
  steps/train_mono.sh  data/tamsa/train_500short data/tamsa/lang exp/tamsa/mono
fi

if [ $stage -le 9 ]; then
  echo "$0: aligning with monophones."
  steps/align_si.sh  data/tamsa/train_500short data/tamsa/lang exp/tamsa/mono exp/tamsa/mono_ali
fi

if [ $stage -le 10 ]; then
  echo "$0: Starting  triphone training in exp/tri1"
  steps/train_deltas.sh \
    --boost-silence 1.25 1000 6000 data/tamsa/train_500short data/tamsa/lang exp/tamsa/mono_ali exp/tamsa/tri1
fi

if [ $stage -le 11 ]; then
  echo "$0: aligning with triphones."
  steps/align_si.sh  data/tamsa/train_500short data/tamsa/lang exp/tamsa/tri1 exp/tamsa/tri1_ali
fi

if [ $stage -le 12 ]; then
  echo "$0: Starting (lda_mllt) triphone training in exp/tri2b"
  steps/train_lda_mllt.sh \
    --splice-opts "--left-context=3 --right-context=3" 500 5000 \
    data/tamsa/train_500short data/tamsa/lang exp/tamsa/tri1_ali exp/tamsa/tri2b
fi

if [ $stage -le 13 ]; then
  echo "$0: aligning with lda and mllt adapted triphones."
  steps/align_si.sh \
    --use-graphs true data/tamsa/train_500short data/tamsa/lang exp/tamsa/tri2b exp/tamsa/tri2b_ali
fi

if [ $stage -le 14 ]; then
  echo "$0: Starting (SAT) triphone training in exp/tri3b"
  steps/train_sat.sh 800 8000 data/tamsa/train_500short data/tamsa/lang exp/tamsa/tri2b_ali exp/tamsa/tri3b
fi

if [ $stage -le 15 ]; then
  echo "$0: Aligning with tri3b models."
  steps/align_fmllr.sh data/tamsa/train_500short data/tamsa/lang exp/tamsa/tri3b exp/tamsa/tri3b_ali
fi

if [ $stage -le 16 ]; then
  echo "Cooking with mini_librispeech recipe."
  mkdir -p $data/mini_librispeech/

  for part in dev-clean-2 train-clean-5; do
    local/mini_librispeech/download_and_untar.sh $data $data_url $part
done
fi

if [ $stage -le 17 ]; then
  local/mini_librispeech/download_lm.sh $lm_url $tmpdir/mini_librispeech/lm
fi

if [ $stage -le 18 ]; then
  for part in dev-clean-2 train-clean-5; do
    echo "Formating the $part data as Kaldi data directories."
    # use underscore-separated names in data directories.
    local/mini_librispeech/data_prep.sh $data/LibriSpeech/$part data/$(echo $part | sed s/-/_/g)
  done
fi

if [ $stage -le 19 ]; then
  local/mini_librispeech/prepare_dict.sh --stage 3 --nj 4 --cmd "$train_cmd" \
    $tmpdir/mini_librispeech/lm $tmpdir/mini_librispeech/lm $tmpdir/mini_librispeech/dict
fi

if [ $stage -le 20 ]; then
  utils/prepare_lang.sh $tmpdir/mini_librispeech/dict \
    "<UNK>" $tmpdir/mini_librispeech/lang_tmp data/mini_librispeech/lang
fi

if [ $stage -le 21 ]; then
  local/mini_librispeech/format_lms.sh --src-dir data/mini_librispeech/lang $tmpdir/mini_librispeech/lm
fi

if [ $stage -le 22 ]; then
  echo "Creating ConstArpaLm format language model for full 3-gram and 4-gram LMs."
  utils/build_const_arpa_lm.sh $tmpdir/mini_librispeech/lm/lm_tglarge.arpa.gz \
    data/mini_librispeech/lang data/mini_librispeech/lang_test_tglarge
fi

if [ $stage -le 23 ]; then
  mfccdir=mfcc_librispeech
  for part in dev_clean_2 train_clean_5; do
    steps/make_mfcc.sh --cmd "$train_cmd" --nj 4 data/mini_librispeech/$part exp/mini_librispeech/make_mfcc/$part $mfccdir
    steps/compute_cmvn_stats.sh data/mini_librispeech/$part exp/mini_librispeech/make_mfcc/$part $mfccdir
  done
fi

if [ $stage -le 24 ]; then
    echo "Getting the shortest 500 utterances."
  utils/subset_data_dir.sh --shortest data/mini_librispeech/train_clean_5 500 data/_mini_librispeech/train_500short
fi

if [ $stage -le 25 ]; then
  echo "Training a monophone system."
  steps/train_mono.sh --boost-silence 1.25 --nj 4 --cmd "$train_cmd" \
    data/mini_librispeech/train_500short data/mini_librispeech/lang exp/mini_librispeech/mono
fi

if [ $stage -le 26 ]; then
  steps/align_si.sh --boost-silence 1.25 --nj 4 --cmd "$train_cmd" \
    data/mini_librispeech/train_500short data/mini_librispeech/lang exp/mini_librispeech/mono exp/mini_librispeech/mono_ali_train_500short
fi

if [ $stage -le 27 ]; then
  echo "Training a first delta + delta-delta triphone system."
  steps/train_deltas.sh --boost-silence 1.25 --cmd "$train_cmd" \
    1000 6000 data/mini_librispeech/train_500short data/mini_librispeech/lang \
    exp/mini_librispeech/mono_ali_train_500short exp/mini_librispeech/tri1
fi

if [ $stage -le 28 ]; then
  steps/align_si.sh --nj 4 --cmd "$train_cmd" \
    data/mini_librispeech/train_500short  data/mini_librispeech/lang exp/mini_librispeech/tri1 exp/mini_librispeech/tri1_ali_train_500short
fi

if [ $stage -le 29 ]; then
  echo "Training an LDA+MLLT system."
  steps/train_lda_mllt.sh --cmd "$train_cmd" \
    --splice-opts "--left-context=3 --right-context=3" 1500 10000 \
    data/mini_librispeech/train_500short data/mini_librispeech/lang exp/mini_librispeech/tri1_ali_train_500short exp/mini_librispeech/tri2b
fi

if [ $stage -le 30 ]; then
  echo "Aligning utts using the tri2b model."
  steps/align_si.sh  --nj 4 --cmd "$train_cmd" --use-graphs true \
    data/mini_librispeech/train_500short data/mini_librispeech/lang exp/mini_librispeech/tri2b exp/mini_librispeech/tri2b_ali_train_500short
fi

if [ $stage -le 31 ]; then
  echo "Training tri3b, which is LDA+MLLT+SAT."
  steps/train_sat.sh --cmd "$train_cmd" 1500 10000 \
    data/mini_librispeech/train_500short data/mini_librispeech/lang exp/mini_librispeech/tri2b_ali_train_500short exp/mini_librispeech/tri3b
fi
exit
# check that link to data/<language>/train exists
for i in $( seq 0 $[$num_langs-1]); do
    if [ ! -d data/${langs[$i]}/train ]; then
	echo "Missing directory data/${langs[$i]}/train"
	exit 1;
    fi

    # check that link to exp/<language>/tri3_ali exists
    if [ ! -d exp/${langs[$i]}/$tri3_ali ]; then
	echo "Missing directory exp/${langs[$i]}/$tri3_ali"
	exit 1;
    fi

    # check that link to data/<language>/lang exists
    if [ ! -d data/${langs[$i]}/lang ]; then
	echo "Missing directory data/${langs[$i]}/lang"
	exit 1;
    fi

    # store links to data/<language>/train in array
    multi_data_dirs[$i]=data/${langs[$i]}/train

    # store paths to directories for examples in array
    multi_egs_dirs[$i]=exp/${langs[$i]}/nnet3/egs

    # store links to alignment directories in array
    multi_tri3_alis[$i]=exp/${langs[$i]}/tri3_ali
done

if [ $stage -le 1 ]; then
    # combine all data for training initial layers 
    mkdir -p $multi_data_dir/train
    combine_lang_list=""
    for i in `seq 0 $[$num_langs-1]`;do
        combine_lang_list="$combine_lang_list data/${langs[$i]}/train"
    done
    utils/combine_data.sh $multi_data_dir/train $combine_lang_list

    utils/validate_data_dir.sh --no-feats $multi_data_dir/train
fi

if [ $stage -le 2 ]; then
    # write configuration file for neural net training
    mkdir -p $dir/configs

    feat_dim=$(feat-to-dim scp:${multi_data_dirs[0]}/feats.scp -)
    opts="l2-regularize=0.004 dropout-proportion=0.0 dropout-per-dim=true dropout-per-dim-continuous=true"
    linear_opts="orthonormal-constraint=-1.0 l2-regularize=0.004"
    output_opts="l2-regularize=0.002"

    cat <<EOF > $dir/configs/network.xconfig
  input dim=$feat_dim name=input
  relu-renorm-layer name=tdnn1 input=Append(input@-2,input@-1,input,input@1,input@2) dim=888
  relu-renorm-layer name=tdnn2 dim=888
  relu-renorm-layer name=tdnn3 input=Append(-1,2) dim=888
  relu-renorm-layer name=tdnn4 input=Append(-3,3) dim=888
  relu-renorm-layer name=tdnn5 input=Append(-3,3) dim=888
  relu-renorm-layer name=tdnn6 input=Append(-7,2) dim=888
EOF

  for i in $(seq 0 $[$num_langs-1]); do
      lang=${langs[$i]}
      num_targets=$(tree-info ${multi_tri3_alis[$i]}/tree 2>/dev/null | grep num-pdfs | awk '{print $2}')

      echo " relu-renorm-layer name=prefinal-affine-lang-${i} input=tdnn6 dim=888"
      echo " output-layer name=output-${i} dim=$num_targets max-change=1.5"
  done >> $dir/configs/network.xconfig

  steps/nnet3/xconfig_to_configs.py \
      --xconfig-file $dir/configs/network.xconfig --config-dir $dir/configs/ \
      --nnet-edits="rename-node old-name=output-0 new-name=output"
fi

if [ $stage -le 3 ]; then
    # get examples
    for i in $(seq 0 $[$num_langs-1]); do
	data=${multi_data_dirs[$i]}
	tri3_ali=${multi_tri3_alis[$i]}
	egs_dir=${multi_egs_dirs[$i]}
	extra_opts=()
	extra_opts+=(--left-context $left_context )
	extra_opts+=(--right-context $right_context )
	local/nnet3/get_egs.sh \
	    --cmvn-opts "--norm-means=false --norm-vars=false" \
	    $egs_opts "${extra_opts[@]}" \
            --samples-per-iter $samples \
	    --stage 0 \
	    $egs_opts \
            --generate-egs-scp true \
            $data \
	    $tri3_ali \
	    $egs_dir
    done
fi

if [ $stage -le 4 ]; then 
    egs_opts="--lang2weight '$lang2weight'"
    common_egs_dir="${multi_egs_dirs[@]} $megs_dir"

    mkdir -p $megs_dir/info
	steps/nnet3/multilingual/combine_egs.sh \
	$egs_opts $num_langs ${common_egs_dir[@]}
fi

if [ $stage -le 5 ]; then
    steps/nnet3/train_raw_dnn.py \
	--cmd="$decode_cmd" \
	--stage=-10 \
	--feat.cmvn-opts="--norm-means=false --norm-vars=false" \
	--trainer.num-epochs 1 \
	--trainer.optimization.num-jobs-initial=1 \
	--trainer.optimization.num-jobs-final=1 \
	--trainer.optimization.initial-effective-lrate=0.0015 \
	--trainer.optimization.final-effective-lrate=0.00015 \
	--trainer.optimization.minibatch-size=256,128 \
	--trainer.samples-per-iter=$samples \
	--trainer.dropout-schedule $dropout_schedule \
	--trainer.max-param-change=2.0 \
	--trainer.srand=0 \
	--feat-dir ${multi_data_dirs[0]} \
	--egs.dir $megs_dir \
	--use-dense-targets false \
	--targets-scp ${multi_tri3_alis[0]} \
	--cleanup.remove-egs true \
	--cleanup.preserve-model-interval 100 \
	--use-gpu true \
	--dir=$dir 
fi

if [ $stage -le 6 ]; then
    for i in $(seq 0 $[$num_langs-1]);do
	l=$dir/${langs[$i]}
	mkdir -p  $l

	nnet3-copy \
	    --edits="rename-node old-name=output-$i new-name=output" \
	    $dir/final.raw $dir/final.edited
    done
fi

if [ $stage -le 7 ]; then
    for i in $(seq 0 $[$num_langs-1]);do
	l=$dir/${langs[$i]}
	nnet3-am-init \
	    exp/${langs[$i]}/tri3_ali/final.mdl $dir/final.edited \
		$l/final.mdl

	    cp $dir/cmvn_opts $l/cmvn_opts
    done
fi

if [ $stage -le 8 ]; then
    echo "$0: compute average posterior and readjust priors"
    for i in $(seq 0 $[$num_langs-1]);do
	l=$dir/${langs[$i]}
	echo "$0:   Adjusting   for ${langs[$i]}."
	steps/nnet3/adjust_priors.sh $l exp/${langs[$i]}/nnet3/egs
    done
fi

if [ $stage -le 10 ]; then
    num_decode_langs=${#decode_langs[@]}
    for i in $(seq 0 $[$num_decode_langs-1]); do
	l=${decode_langs[$i]}
	echo "Decoding lang $l"
	echo "using multilingual hybrid model in $dir"

	score_opts="--skip-scoring false"

	for fld in dev devtest test; do
	    steps/nnet3/decode.sh \
		--iter final_adj --stage -1 --beam 16.0 --lattice-beam 8.5 \
		exp/$l/tri3/graph \
	    data/$l/$fld $dir/$l/decode_${fld}
	done
    done
fi
exit 0
