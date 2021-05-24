#!/usr/bin/env bash

# chain2 recipe for  AfricanAccented French Yaounde and MLS French.
# Yaounde task uses transcripts to train its LM
# weights set to 0.90 0.10
# Copyright 2016 Pegah Ghahremani
# Copyright 2020 Srikanth Madikeri (Idiap Research Institute)

# Train a multilingual LF-MMI system with a multi-task training setup.
# This script assumes the following 2 recipes have been run:
# - ../s5c/run.sh 
# ../../mls_fr/s5/run.sh

set -e -o pipefail

sfive=/mnt/disk02/jjm/yaounde+/s5c
# language dependent variable settings
dir=exp/chain2_multi
# the order of the elements in the following listss is important
egs_dir_list="$dir/yaounde_processed_egs $dir/mls_fr_processed_egs"
# The following variable is hard coded in local/combine_egs.sh
# TODO: pass it from this script
lang2weight="0.90,0.10"
lang_list=(yaounde mls_fr)
num_langs=2

# Start setting other variables
boost_sil=1.0 # Factor by which to boost silence likelihoods in alignment
chunk_width=150
cmd=run.pl
common_egs_dir=  # you can set this to use previously dumped egs.
decode_lang_list=(yaounde)
extra_left_context=50
extra_right_context=0
final_effective_lrate=0.0001
frame_subsampling_factor=3
gmm=tri3b  # the gmm for the target data
initial_effective_lrate=0.001
langdir=data/lang
lda_mllt_lang=yaounde
max_param_change=2.0
memory_compression_level=0
minibatch_size=128
nj=30
num_epochs=4.0
numGaussUBM=512
num_jobs_final=2
num_jobs_initial=2
srand=-1
stage=-1
train_set=train
train_stage=-10
xent_regularize=0.1
# done setting variables

. ./path.sh
. ./cmd.sh
. ./utils/parse_options.sh

if ! cuda-compiled; then
  cat <<EOF
This script is intended to be used with GPUs but you have not compiled Kaldi with CUDA
If you want to use GPUs (and have them), go to src/, and configure and make on a machine
where "nvcc" is installed.
EOF
fi

if [ $stage -le 0 ]; then
  (
    [ -d data ] || mkdir -p data;
    cd data
    echo "$0: Link data directories from yaounde."
    [ -L data ] || ln -s $sfive/data/ data/yaounde;
  )
  # link exp directories from yaounde
  (
    echo "Link exp directories from yaounde."
    [ -d exp/yaounde ] || mkdir -p exp/yaounde;
    cd exp/yaounde
    [ -L exp ] || ln -s $sfive/exp ./;
  )

  # link  MLS FR data directories
  (
    echo "Link data directories from MLS FR ."
    [ -d data/mls_fr ] || mkdir -p data/mls_fr;
    cd data/mls_fr
    [ -L lang ] || ln -s ../../../../mls_fr/s5/data/lang ./;
    [ -L lang_test ] || ln -s ../../../../mls_fr/s5/data/lang_test ./;
    [ -L train ] || ln -s ../../../../mls_fr/s5/data/train ./;
  )

  # link mls fr exp directories
  (
    echo "Link mls fr exp directories."
    [ -d exp/mls_fr ] || mkdir -p exp/mls_fr;
    cd exp/mls_fr
    [ -L tri3b ] || ln -s ../../../../mls_fr/s5/exp/tri5b ./tri3b;
    [ -L tri3b_ali ] || ln -s ../../../../mls_fr/s5/exp/tri5b_ali ./tri3b_ali;
  )
fi

if [ $stage -le 1 ]; then
  for lang in ${lang_list[@]};do
    echo "$0: Generating raw egs for $lang"
    train_ivector_dir=exp/$lang/ivectors_train_sp_hires
    train_data_dir=data/$lang/train_sp_hires
    lat_dir=exp/$lang/chain/tri3b_train_sp_lats
    steps/chain2/get_raw_egs.sh \
      --alignment-subsampling-factor $frame_subsampling_factor \
      --cmd "$train_cmd" \
      --frame-subsampling-factor $frame_subsampling_factor \
      --frames-per-chunk $chunk_width \
      --lang "$lang" \
      --left-context $egs_left_context \
      --online-ivector-dir $train_ivector_dir \
      --right-context $egs_right_context \
      ${train_data_dir} \
      ${dir} \
      ${lat_dir} \
      $dir/${lang}_raw_egs || exit 1

    echo "$0: Processing raw egs for $lang"
    steps/chain2/process_egs.sh  \
      --cmd "$train_cmd" \
      $dir/${lang}_raw_egs \
      ${dir}/${lang}_processed_egs || exit 1
  done
fi

if [ $stage -le 2 ]; then
    egs_opts="$lang2weights"
  echo "$0: Combining egs"
  local/combine_egs.sh \
    $egs_opts \
    --cmd "$train_cmd" \
    $num_langs \
    $egs_dir_list \
    $dir/egs
fi
[[ -z $common_egs_dir ]] && common_egs_dir=$dir/egs

if [ $stage -le 3 ]; then
  [ ! -d $dir/egs/misc ] && mkdir  $dir/egs/misc
  echo "$0: Copying den.fst to $dir/egs/misc"
  for lang in ${lang_list[@]};do
    cp $dir/den_fsts/${lang}.*fst $dir/egs/misc/
    cp $dir/init/${lang}_trans.mdl $dir/egs/misc/${lang}.trans_mdl
    [ -L $dir/egs/info_${lang}.txt ] || ln -rs $dir/egs/info.txt $dir/egs/info_${lang}.txt
  done
  echo "$0: Create a dummy transition model that is never used."
  first_lang_name=yaounde
  [[ ! -f $dir/init/default_trans.mdl ]] && ln -r -s $dir/init/${first_lang_name}_trans.mdl $dir/init/default_trans.mdl
fi

if [ $stage -le 4 ]; then
  echo "$0: Preparing initial acoustic model"
  $cuda_cmd $dir/log/init_model.log \
  nnet3-init \
    --srand=${srand} \
    $dir/configs/final.config \
    $dir/init/multi.raw || exit 1
fi

if [ $stage -le 5 ]; then
  echo "$0: Starting model training"
  [ -f $dir/.error ] && echo "WARNING: $dir/.error exists";
  steps/chain2/train.sh \
    --cmd "$cuda_cmd" \
    --final-effective-lrate $final_effective_lrate \
    --initial-effective-lrate $initial_effective_lrate \
    --l2-regularize 5e-5 \
    --leaky-hmm-coefficient 0.25  \
    --max-param-change $max_param_change \
    --memory-compression-level $memory_compression_level \
    --minibatch-size $minibatch_size \
    --multilingual-eg true \
    --num-epochs $num_epochs \
    --num-jobs-final $num_jobs_final \
    --num-jobs-initial $num_jobs_initial \
    --shuffle-buffer-size 5000 \
    --srand 1 \
    --stage $train_stage \
    --xent-regularize $xent_regularize \
    $common_egs_dir \
    $dir
fi

if [ $stage -le 6 ]; then
  echo "$0: Splitting models"
  ivector_dim=$(feat-to-dim scp:exp/yaounde/ivectors_train_sp_hires/ivector_online.scp -) || exit 1;
  feat_dim=$(feat-to-dim scp:data/yaounde/train_sp_hires/feats.scp -)
  frame_subsampling_factor=$(fgrep "frame_subsampling_factor" $dir/init/info.txt | awk '{print $2}')
  for lang in ${lang_list[@]};do
    [[ ! -d $dir/$lang ]] && mkdir $dir/$lang
    nnet3-copy --edits="rename-node old-name=output new-name=output-dummy; rename-node old-name=output-$lang new-name=output" \
      $dir/final.raw - | \
      nnet3-am-init $dir/init/${lang}_trans.mdl - $dir/$lang/final.mdl
    [[ ! -d $dir/$lang/init ]] && mkdir $dir/$lang/init
    params="frame_subsampling_factor model_left_context model_right_context feat_dim left_context left_context_initial right_context right_context_final ivector_dim frames_per_chunk"
    for param_name in $params; do
      grep -m 1 "^$param_name " $dir/init/info.txt
    done > $dir/$lang/init/info.txt
  done
fi

if [ $stage -le 7 ]; then
  # Decode ca16 with yaounde task
  tree_dir=exp/yaounde
  utils/mkgraph.sh \
    --self-loop-scale 1.0 \
    data/yaounde/lang_test \
    $tree_dir \
    $tree_dir/graph || exit 1;
fi

if [ $stage -le 8 ]; then
  frames_per_chunk=$(echo $chunk_width | cut -d, -f1)
  # Extract high resolution MFCCs from  ca16 data
  for f in  ca16; do
    utils/copy_data_dir.sh \
      data/yaounde/$f \
      data/yaounde/${f}_hires || exit 1;
    steps/make_mfcc.sh \
      --cmd "$train_cmd" \
      --mfcc-config conf/mfcc_hires.conf \
      --nj 2 \
      data/yaounde/${f}_hires || exit 1;
    steps/compute_cmvn_stats.sh \
      data/yaounde/${f}_hires || exit 1;
    utils/fix_data_dir.sh data/yaounde/${f}_hires || exit 1;
    # Do the  decoding pass
    steps/online/nnet2/extract_ivectors_online.sh \
      --cmd "$train_cmd" \
      --nj 2 \
      data/yaounde/${f}_hires \
      exp/multi/extractor \
      exp/yaounde/ivectors_${f}_hires || exit 1;

    (
      nspk=$(wc -l <data/yaounde/${f}_hires/spk2utt)
      tree_dir=exp/yaounde || exit 1;
      steps/nnet3/decode.sh \
        --acwt 1.0 \
        --cmd "$decode_cmd"  \
        --extra-left-context $egs_left_context \
        --extra-left-context-initial 0 \
        --extra-right-context $egs_right_context \
        --extra-right-context-final 0 \
        --frames-per-chunk $frames_per_chunk \
        --nj $nspk \
        --num-threads 4 \
        --online-ivector-dir exp/yaounde/ivectors_${f}_hires \
        --post-decode-acwt 10.0 \
        $tree_dir/graph \
        data/yaounde/${f}_hires \
        exp/chain2_multi/yaounde/decode_${f}_hires || exit 1
    )
  done
fi

if [ $stage -le 9 ]; then
  # Decode ca16 with MLS  task
  tree_dir=exp/mls_fr
  utils/mkgraph.sh \
    --self-loop-scale 1.0 \
    data/mls_fr/lang_test \
    $tree_dir \
    $tree_dir/graph || exit 1;
fi

if [ $stage -le 10 ]; then
  # Do the  decoding pass
  frames_per_chunk=$(echo $chunk_width | cut -d, -f1)
  (
    nspk=$(wc -l <data/yaounde/ca16_hires/spk2utt)
    tree_dir=exp/mls_fr || exit 1;
    steps/nnet3/decode.sh \
      --acwt 1.0 \
      --cmd "$decode_cmd"  \
      --extra-left-context $egs_left_context \
      --extra-left-context-initial 0 \
      --extra-right-context $egs_right_context \
      --extra-right-context-final 0 \
      --frames-per-chunk $frames_per_chunk \
      --nj $nspk \
      --num-threads 4 \
      --online-ivector-dir exp/yaounde/ivectors_ca16_hires \
      --post-decode-acwt 10.0 \
      $tree_dir/graph \
      data/yaounde/ca16_hires \
      exp/chain2_multi/mls_fr/decode_ca16_hires || exit 1
  )
fi
