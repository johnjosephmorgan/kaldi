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
# Variables for mini librispeech
data=data_librispeech
data_url=www.openslr.org/resources/31
# Variables for mtl training
# input languages
langs[0]="mini_librispeech"
langs[1]="tamsa"
dir=exp/multi;  # working directory
# directory for consolidated data preparation
multi_data_dir=data/multi;
decode_langs=( tamsa mini_librispeech );
decode_tamsa_folds=( devtest test );
decode_mini_librispeech_folds=( dev_clean_2 );
lang2weight="0.2,0.8";  # weighting of input languages
lang_weights=(0.2 0.8 );
left_context=19;  # context frames
right_context=14;
samples=300000;  # samples per iteration 
num_langs=${#langs[@]};
num_weights=${#lang_weights[@]};
megs_dir=$dir/egs
dropout_schedule='0,0@0.20,0.5@0.50,0'

for i in `seq 0 $[$num_langs-1]`;do
  # store  paths to data/<language>/train in array
  multi_data_dirs[$i]=data/${langs[$i]}/train
  # store paths to directories for examples in array
  multi_egs_dirs[$i]=exp/${langs[$i]}/nnet3/egs
  # store  alignment directories in array
  multi_tri3_alis[$i]=exp/${langs[$i]}/tri3b_ali
done
# End of Configuration variables settings

. ./path.sh
. ./cmd.sh
. ./utils/parse_options.sh

if [ $stage -le 1 ]; then
  # Downloads archive to this script's directory
  local/tamsa/download.sh $speech

  local/qcri_lexicon_download.sh $lex
fi

# preparation stages will store files under data/
# Delete the entire data directory when restarting.
if [ $stage -le 2 ]; then
    local/tamsa/build_acoustic_models.sh
fi

if [ $stage -le 3 ]; then
  echo "Cooking with mini_librispeech recipe."
  mkdir -p $data/mini_librispeech

  for part in dev-clean-2 train-clean-5; do
    local/mini_librispeech/download_and_untar.sh $data $data_url $part
done
fi

if [ $stage -le 4 ]; then
  local/mini_librispeech/build_acoustic_models.sh
fi

if [ $stage -le 5 ]; then
  echo "$0: combining all data for training initial layers." 
  mkdir -p $multi_data_dir/train
  combine_lang_list=""

  for i in `seq 0 $[$num_langs-1]`;do
    combine_lang_list="$combine_lang_list data/${langs[$i]}/train"
  done
  utils/combine_data.sh $multi_data_dir/train $combine_lang_list

  utils/validate_data_dir.sh --no-feats $multi_data_dir/train
fi

if [ $stage -le 6 ]; then
  echo "Writing configuration file for neural net training."
  mkdir -p $dir/configs

  feat_dim=$(feat-to-dim scp:${multi_data_dirs[0]}/feats.scp -)
  opts="l2-regularize=0.004 dropout-proportion=0.0 dropout-per-dim=true dropout-per-dim-continuous=true"
  linear_opts="orthonormal-constraint=-1.0 l2-regularize=0.004"
  output_opts="l2-regularize=0.002"

  cat <<EOF > $dir/configs/network.xconfig
  input dim=$feat_dim name=input
  relu-renorm-layer name=tdnn1 input=Append(input@-2,input@-1,input,input@1,input@2) dim=256
  relu-renorm-layer name=tdnn2 dim=256
  relu-renorm-layer name=tdnn3 input=Append(-1,2) dim=256
  relu-renorm-layer name=tdnn4 input=Append(-3,3) dim=256
  relu-renorm-layer name=tdnn5 input=Append(-3,3) dim=256
  relu-renorm-layer name=tdnn6 input=Append(-7,2) dim=256
EOF

  for i in $(seq 0 $[$num_langs-1]); do
    lang=${langs[$i]}
    num_targets=$(tree-info ${multi_tri3_alis[$i]}/tree 2>/dev/null | grep num-pdfs | awk '{print $2}')

    echo " relu-renorm-layer name=prefinal-affine-lang-${i} input=tdnn6 dim=256"
    echo " output-layer name=output-${i} dim=$num_targets max-change=1.5"
  done >> $dir/configs/network.xconfig

  steps/nnet3/xconfig_to_configs.py \
    --xconfig-file $dir/configs/network.xconfig --config-dir $dir/configs/ \
    --nnet-edits="rename-node old-name=output-0 new-name=output"
fi

if [ $stage -le 7 ]; then
  echo "$0: Getting examples."
  for i in $(seq 0 $[$num_langs-1]); do
    data=${multi_data_dirs[$i]}
    tri3_ali=${multi_tri3_alis[$i]}
    egs_dir=${multi_egs_dirs[$i]}
    extra_opts=()
    extra_opts+=(--left-context $left_context )
    extra_opts+=(--right-context $right_context )
    local/nnet3/get_egs.sh \
      --cmvn-opts "--norm-means=false --norm-vars=false" \
      "${extra_opts[@]}" \
      --samples-per-iter $samples \
      --stage 0 \
      --generate-egs-scp true \
      $data \
      $tri3_ali \
      $egs_dir
  done
fi

if [ $stage -le 8 ]; then 
  egs_opts="--lang2weight '$lang2weight'"
  common_egs_dir="${multi_egs_dirs[@]} $megs_dir"

  mkdir -p $megs_dir/info
  steps/nnet3/multilingual/combine_egs.sh \
    $egs_opts $num_langs ${common_egs_dir[@]}
fi

if [ $stage -le 9 ]; then
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

if [ $stage -le 10 ]; then
  for i in $(seq 0 $[$num_langs-1]);do
    l=$dir/${langs[$i]}
    mkdir -p  $l

    nnet3-copy \
      --edits="rename-node old-name=output-$i new-name=output" \
      $dir/final.raw $dir/final.edited
  done
fi

if [ $stage -le 11 ]; then
  for i in $(seq 0 $[$num_langs-1]);do
    l=$dir/${langs[$i]}
    nnet3-am-init \
    exp/${langs[$i]}/tri3b_ali/final.mdl $dir/final.edited \
    $l/final.mdl

    cp $dir/cmvn_opts $l/cmvn_opts
  done
fi

if [ $stage -le 12 ]; then
  echo "$0: compute average posterior and readjust priors"
  for i in $(seq 0 $[$num_langs-1]);do
    l=$dir/${langs[$i]}
    echo "$0:   Adjusting   for ${langs[$i]}."
    steps/nnet3/adjust_priors.sh $l exp/${langs[$i]}/nnet3/egs
  done
fi

if [ $stage -le 13 ]; then
  mkdir -p data/tamsa/lm
  cut -d " " -f 2- data/tamsa/train/text > data/tamsa/lm/train.txt
  local/tamsa/prepare_small_lm.sh data/tamsa/lm/train.txt
fi

if [ $stage -le 14 ]; then
  echo "Making G.fst for tamsa."
  utils/format_lm.sh data/tamsa/lang data/tamsa/lm/tgsmall.arpa.gz $tmpdir/tamsa/dict/lexicon.txt \
    data/tamsa/lang_test

  echo "$0: Making decoding graphs for tamsa tri3b SAT models."
  utils/mkgraph.sh data/tamsa/lang_test exp/tamsa/tri3b exp/tamsa/tri3b/graph
fi

if [ $stage -le 15 ]; then
  echo "Making G.fst for mini librispeech."
  utils/format_lm.sh data/mini_librispeech/lang data/mini_librispeech/lm/tgsmall.arpa.gz \
    $tmpdir/mini_librispeech/dict/lexicon.txt data/mini_librispeech/lang_test

  echo "$0: Making decoding graphs for mini librispeech  tri3b SAT models."
  utils/mkgraph.sh data/mini_librispeech/lang_test_tgsmall \
    exp/mini_librispeech/tri3b exp/mini_librispeech/tri3b/graph
fi

if [ $stage -le 16 ]; then
  for x in ${decode_tamsa_folds[@]}; do
    echo "$0: Decoding $x with tamsa tri3b models."
    nspk=$(wc -l < data/tamsa/$x/spk2utt)
    steps/decode_fmllr.sh --nj $nspk exp/tamsa/tri3b/graph data/tamsa/$x \
      exp/tamsa/tri3b/decode_${x}
  done

  for x in ${decode_mini_librispeech_folds[@]}; do
    echo "$0: Decoding $x with mini librispeech tri3b models."
    nspk=$(wc -l < data/mini_librispeech/$x/spk2utt)
    steps/decode_fmllr.sh --nj $nspk exp/mini_librispeech/tri3b/graph \
    data/mini_librispeech/$x exp/mini_librispeech/tri3b/decode_${x}
  done
  echo "Decoding using multilingual hybrid model in $dir"
  score_opts="--skip-scoring false"
  for fld in ${decode_tamsa_folds[@]}; do
    nspk=$(wc -l <data/tamsa/$fld/spk2utt)
    steps/nnet3/decode.sh --nj $nspk \
      --frames-per-chunk 250 \
      --iter final_adj --stage -1 --beam 16.0 --lattice-beam 8.5 \
      exp/tamsa/tri3b/graph \
        data/tamsa/$fld $dir/tamsa/decode_${fld}
  done
  score_opts="--skip-scoring false"
  for fld in ${decode_mini_librispeech_folds[@]}; do
    nspk=$(wc -l <data/mini_librispeech/$fld/spk2utt)
    steps/nnet3/decode.sh --nj $nspk \
      --frames-per-chunk 50 \
      --iter final_adj --stage -1 --beam 16.0 --lattice-beam 8.5 \
      exp/mini_librispeech/tri3b/graph \
      data/mini_librispeech/$fld $dir/mini_librispeech/decode_${fld}
  done
fi
exit 0
