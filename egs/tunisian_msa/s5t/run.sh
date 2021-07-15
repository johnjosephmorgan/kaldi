#!/usr/bin/env bash

# chain2 recipe for  Tunisian MSA, globalphone tunisian,  gale_arabic and MSA MFLTS.
# Weights are uniformely distributed
# Copyright 2016 Pegah Ghahremani
# Copyright 2020 Srikanth Madikeri (Idiap Research Institute)

# Train a multilingual LF-MMI system with a multi-task training setup.
# This script assumes the following 4 recipes have been run:
# - ../s5m/run.sh 
# ../../globalphone_tunisian/s5/run.sh
# ../../gale_arabic/s5d/run.sh
# ../../msa_mflts/s5/run.sh

set -e -o pipefail

# language dependent variable settings
dir=exp/chain2_multi
# the order of the elements in the following listss is important
egs_dir_list="$dir/tunisian_msa_processed_egs $dir/globalphone_tunisian_processed_egs $dir/gale_arabic_processed_egs $dir/msa_mflts_processed_egs"
lang2weight="0.25,0.25,0.25,0.25"
lang_list=(tunisian_msa globalphone_tunisian gale_arabic msa_mflts)
num_langs=4

# Start setting other variables
boost_sil=1.0 # Factor by which to boost silence likelihoods in alignment
chunk_width=150
cmd=run.pl
common_egs_dir=  # you can set this to use previously dumped egs.
decode_lang_list=(tunisian_msa)
extra_left_context=50
extra_right_context=0
final_effective_lrate=0.0001
frame_subsampling_factor=3
gmm=tri3b  # the gmm for the target data
initial_effective_lrate=0.001
langdir=data/lang
lda_mllt_lang=tunisian_msa
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
    echo "$0: Link data directories from tunisian_msa."
    [ -d data/tunisian_msa ] || mkdir -p data/tunisian_msa;
    cd data/tunisian_msa
    # link the lang directory
    [ -L lang ] || ln -s ../../../s5m/data/lang ./;
    # link the train directory
    [ -L train ] || ln -s ../../../s5m/data/train ./;
    # link the test directory
    [ -L test ] || ln -s ../../../s5m/data/test ./;
    # link the lang_test directory
    [ -L lang_test ] || ln -s ../../../s5m/data/lang_test ./;
  )

  # link exp directories from tunisian_msa
  (
    echo "Link exp directories from tunisian_msa."
    [ -d exp/tunisian_msa ] || mkdir -p exp/tunisian_msa;
    cd exp/tunisian_msa
    # link the tri3b directory
    [ -L tri3b ] || ln -s ../../../s5m/exp/tri3b ./;
    # link the tri3b_ali
    [ -L tri3b_ali ] || ln -s ../../../s5m/exp/tri3b_ali ./;
  )

  # link globalphone tunisian data directories
  (
    echo "Link data directories from globalphone tunisian ."
    [ -d data/globalphone_tunisian ] || mkdir -p data/globalphone_tunisian;
    cd data/globalphone_tunisian
    [ -L lang ] || ln -s ../../../../globalphone_tunisian/s5/data/lang ./;
    [ -L lang_test ] || ln -s ../../../../globalphone_tunisian/s5/data/lang_test ./;
    [ -L train ] || ln -s ../../../../globalphone_tunisian/s5/data/train ./;
  )

  # link globalphone_tunisian exp directories
  (
    echo "Link globalphone_tunisian exp directories."
    [ -d exp/globalphone_tunisian ] || mkdir -p exp/globalphone_tunisian;
    cd exp/globalphone_tunisian
    [ -L tri3b ] || ln -s ../../../../globalphone_tunisian/s5/exp/tri3b ./;
    [ -L tri3b_ali ] || ln -s ../../../../globalphone_tunisian/s5/exp/tri3b_ali ./;
  )

  # link gale arabic data directories
  (
    echo "Link data directories from gale arabic ."
    [ -d data/gale_arabic ] || mkdir -p data/gale_arabic;
    cd data/gale_arabic
    [ -L lang ] || ln -s ../../../../gale_arabic/s5d/data/lang ./;
    [ -L lang_test ] || ln -s ../../../../gale_arabic/s5d/data/lang_test ./;
    [ -L train ] || ln -s ../../../../gale_arabic/s5d/data/train ./;
  )

  # link gale_arabic exp directories
  (
    echo "Link gale_arabic exp directories."
    [ -d exp/gale_arabic ] || mkdir -p exp/gale_arabic;
    cd exp/gale_arabic
    [ -L tri3b ] || ln -s ../../../../gale_arabic/s5d/exp/tri3b ./;
    [ -L tri3b_ali ] || ln -s ../../../../gale_arabic/s5d/exp/tri3b_ali ./;
  )

  # link msa mflts  data directories
  (
    echo "Link data directories from msa mflts ."
    [ -d data/msa_mflts ] || mkdir -p data/msa_mflts;
    cd data/msa_mflts
    [ -L lang ] || ln -s ../../../../msa_mflts/s5/data/lang ./;
    [ -L train ] || ln -s ../../../../msa_mflts/s5/data/train ./;
  )

  # link msa_mflts exp directories
  (
    echo "Link msa_mflts exp directories."
    [ -d exp/msa_mflts ] || mkdir -p exp/msa_mflts;
    cd exp/msa_mflts
    [ -L tri3b ] || ln -s ../../../../msa_mflts/s5/exp/tri3b ./;
    [ -L tri3b_ali ] || ln -s ../../../../msa_mflts/s5/exp/tri3b_ali ./;
  )
fi

if [ $stage -le 1 ]; then
  for lang in ${lang_list[@]}; do
    echo "Speed perturbing $lang training data."
    ./utils/data/perturb_data_dir_speed_3way.sh \
      data/$lang/train \
      data/$lang/train_sp
    # Extract  features for perturbed $lang data.
    steps/make_mfcc.sh \
      --cmd "$train_cmd" \
      --nj 16 \
      data/$lang/train_sp 
    steps/compute_cmvn_stats.sh \
      data/$lang/train_sp
    utils/fix_data_dir.sh data/$lang/train_sp
    echo "Get alignments for perturbed $lang training data."
    steps/align_fmllr.sh \
      --boost-silence $boost_sil \
      --cmd "$train_cmd" \
      --nj 16 \
      data/$lang/train_sp \
      data/$lang/lang \
      exp/$lang/tri3b \
      exp/$lang/tri3b_ali_sp || exit 1;
    echo "Extract high resolution 40dim MFCCs"
    utils/copy_data_dir.sh \
      data/$lang/train_sp\
      data/$lang/train_sp_hires || exit 1;
    steps/make_mfcc.sh \
      --cmd "$train_cmd" \
      --mfcc-config conf/mfcc_hires.conf \
      --nj 16 \
      data/$lang/train_sp_hires || exit 1;
    steps/compute_cmvn_stats.sh \
      data/$lang/train_sp_hires || exit 1;
    utils/fix_data_dir.sh data/$lang/train_sp_hires || exit 1;
  done
fi

if [ $stage -le 2 ]; then
  mkdir -p data/multi exp/multi
  multi_data_dir_for_ivec=data/multi/train_sp_hires
  echo "$0: combine training data from all langs to training i-vector extractor."
  echo "Pooling training data in $multi_data_dir_for_ivec on" $(date)
  mkdir -p $multi_data_dir_for_ivec
  combine_lang_list=""
  for lang in ${lang_list[@]};do
    utils/copy_data_dir.sh \
      --spk-prefix ${lang}- \
      --utt-prefix ${lang}- \
      data/$lang/train_sp_hires \
      data/$lang/train_sp_hires_prefixed || exit 1
    combine_lang_list="$combine_lang_list data/$lang/train_sp_hires_prefixed"
  done
  utils/combine_data.sh $multi_data_dir_for_ivec $combine_lang_list
  utils/validate_data_dir.sh --no-feats $multi_data_dir_for_ivec
fi

if [ $stage -le 3 ]; then
  # Compute PCA transform
  steps/online/nnet2/get_pca_transform.sh \
    --cmd "$train_cmd" \
    --splice-opts "--left-context=3 --right-context=3" \
    --max-utts 10000 \
    --subsample 2 \
    data/$lda_mllt_lang/train_sp_hires \
    exp/$lda_mllt_lang/tri_lda_mllt
fi

if [ $stage -le 4 ]; then
  # Train a diagonal universal background model
  steps/online/nnet2/train_diag_ubm.sh \
    --cmd "$train_cmd" \
    --nj 87 \
    --num-frames 200000 \
    data/$lda_mllt_lang/train_sp_hires \
    $numGaussUBM \
    exp/$lda_mllt_lang/tri_lda_mllt \
    exp/multi/diag_ubm || exit 1;
fi

if [ $stage -le 5 ]; then
  steps/online/nnet2/train_ivector_extractor.sh \
    --cmd "$train_cmd" \
    --nj 50 \
    data/multi/train_sp_hires \
    exp/multi/diag_ubm \
    exp/multi/extractor || exit 1;
fi

if [ $stage -le 6 ]; then
  echo "$0: Extracts ivector for all languages  ."
  for lang in ${lang_list[@]}; do
    utils/data/modify_speaker_info.sh \
      --utts-per-spk-max 2 \
      data/$lang/train_sp_hires \
      data/$lang/train_sp_hires_max2 || exit 1;

    steps/online/nnet2/extract_ivectors_online.sh \
      --cmd "$train_cmd" \
      --nj 200 \
      data/$lang/train_sp_hires_max2 \
      exp/multi/extractor \
      exp/$lang/ivectors_train_sp_hires || exit 1;
  done
fi

dir_basename=$(basename $dir)
for lang in ${lang_list[@]}; do
  multi_lores_data_dirs[${lang}]=data/$lang/train_sp
  multi_data_dirs[${lang}]=data/$lang/train_sp_hires
  multi_egs_dirs[${lang}]=exp/$lang/egs
  multi_ali_dirs[${lang}]=exp/$lang
  multi_ivector_dirs[${lang}]=exp/$lang/ivectors_train_sp_hires
  multi_ali_treedirs[${lang}]=exp/$lang
  multi_ali_latdirs[${lang}]=exp/$lang/chain/tri3b_train_sp_lats
  multi_lang[${lang}]=data/$lang/lang
  multi_lfmmi_lang[${lang}]=data/$lang/lang_chain
  multi_gmm_dir[${lang}]=exp/$lang/tri3b
  multi_chain_dir[${lang}]=exp/$lang/chain/$dir_basename
done

ivector_dim=$(feat-to-dim scp:exp/tunisian_msa/ivectors_train_sp_hires/ivector_online.scp -) || exit 1;
feat_dim=$(feat-to-dim scp:data/tunisian_msa/train_sp_hires/feats.scp -)

if [ $stage -le 7 ]; then
  for lang in ${lang_list[@]};do
    if [ -d data/$lang/lang_chain ]; then
      if [ data/$lang/lang_chain/L.fst -nt data/$lang/lang/L.fst ]; then
        echo "$0: data/$lang/lang_chain already exists, not overwriting it; continuing"
      else
        echo "$0: data/$lang/lang_chain already exists and seems to be older than data/$lang/lang ..."
        echo " ... not sure what to do.  exiting."
        exit 1;
      fi
    else
      echo "$0: creating lang directory with one state per phone for data/${lang}."
      cp -r data/$lang/lang/ data/$lang/lang_chain # trailing slash makes sure soft links are copied
      silphonelist=$(cat data/$lang/lang_chain/phones/silence.csl) || exit 1;
      nonsilphonelist=$(cat data/$lang/lang_chain/phones/nonsilence.csl) || exit 1;
      # Use our special topology... note that later on may have to tune this
      # topology.
      steps/nnet3/chain/gen_topo.py \
        $nonsilphonelist \
 $silphonelist > data/$lang/lang_chain/topo
    fi
  done
fi

if [ $stage -le 8 ]; then
  # Get the alignments as lattices (gives the chain training more freedom).
  # use the same num-jobs as the alignments
  for lang in ${lang_list[@]};do
    # Get alignments for languages separately
    langdir=data/$lang/lang
    # Use low resolution features
    lores_train_data_dir=data/$lang/train_sp
    # Use tri3b in this recipe
    gmm_dir=exp/$lang/tri3b
    lat_dir=exp/$lang/chain/tri3b_train_sp_lats
    steps/align_fmllr_lats.sh \
      --cmd "$train_cmd" \
      --nj $nj \
      $lores_train_data_dir \
      $langdir \
      $gmm_dir \
      $lat_dir
    rm $lat_dir/fsts.*.gz # save space
  done
fi 

if [ $stage -le 9 ]; then
  for lang in ${lang_list[@]};do
    # A tree for each separate language
    echo "$0: Building tree for $lang"
    tree_dir=exp/$lang
    # low resolution
    ali_dir=exp/$lang/tri3b_ali_sp
    lores_train_data_dir=data/$lang/train_sp
    lang_dir=data/$lang/lang_chain
    steps/nnet3/chain/build_tree.sh \
      --cmd "$train_cmd" \
      --context-opts "--context-width=2 --central-position=1" \
      --frame-subsampling-factor $frame_subsampling_factor \
      --leftmost-questions-truncate -1 \
      4000 \
      $lores_train_data_dir \
      $lang_dir \
      $ali_dir \
      $tree_dir
  done
fi

if [ $stage -le 10 ]; then
  echo "$0: creating multilingual neural net configs using the xconfig parser";
  ivector_dim=$(feat-to-dim scp:exp/tunisian_msa/ivectors_train_sp_hires/ivector_online.scp -) || exit 1;
  feat_dim=$(feat-to-dim scp:data/tunisian_msa/train_sp_hires/feats.scp -)
  if [ -z $bnf_dim ]; then
    bnf_dim=80
  fi
  mkdir -p $dir/configs
  ivector_node_xconfig=""
  ivector_to_append=""
  if $use_ivector; then
    ivector_node_xconfig="input dim=$ivector_dim name=ivector"
    ivector_to_append=", ReplaceIndex(ivector, t, 0)"
  fi
  learning_rate_factor=$(echo "print (0.5/$xent_regularize)" | python)
  dummy_tree_dir=exp/tunisian_msa
  num_targets=$(tree-info $dummy_tree_dir/tree 2>/dev/null | grep num-pdfs | awk '{print $2}') || exit 1;
  cat <<EOF > $dir/configs/network.xconfig
  input dim=$feat_dim name=input
  $ivector_node_xconfig

  # please note that it is important to have input layer with the name=input
  # as the layer immediately preceding the fixed-affine-layer to enable
  # the use of short notation for the descriptor
  # the first splicing is moved before the lda layer, so no splicing here
  relu-batchnorm-layer name=tdnn1 input=Append(input@-2,input@-1,input,input@1,input@2$ivector_to_append) dim=450
  relu-batchnorm-layer name=tdnn2 input=Append(-1,0,1,2) dim=450
  relu-batchnorm-layer name=tdnn4 input=Append(-3,0,3) dim=450
  relu-batchnorm-layer name=tdnn5 input=Append(-3,0,3) dim=450
  relu-batchnorm-layer name=tdnn6 input=Append(-3,0,3) dim=450
  relu-batchnorm-layer name=tdnn7 input=Append(-6,-3,0) dim=450
  #relu-batchnorm-layer name=tdnn_bn dim=$bnf_dim
  # adding the layers for diffrent language's output
  # dummy output node
  output-layer name=output dim=$num_targets max-change=1.5 include-log-softmax=false
  output-layer name=output-xent input=tdnn7 dim=$num_targets learning-rate-factor=$learning_rate_factor max-change=1.5
EOF
  # added separate outptut layer and softmax for all languages.
  for lang in ${lang_list[@]};do
    tree_dir=exp/$lang
    num_targets=$(tree-info $tree_dir/tree 2>/dev/null | grep num-pdfs | awk '{print $2}') || exit 1;

    #echo "relu-renorm-layer name=prefinal-affine-lang-${lang_name} input=tdnn7 dim=450 target-rms=0.5"
    echo "output-layer name=output-${lang} dim=$num_targets input=tdnn7  max-change=1.5 include-log-softmax=false"
    echo "output-layer name=output-${lang}-xent input=tdnn7 dim=$num_targets  learning-rate-factor=$learning_rate_factor max-change=1.5"
  done >> $dir/configs/network.xconfig

  lang_name=tunisian_msa
  steps/nnet3/xconfig_to_configs.py --xconfig-file $dir/configs/network.xconfig \
    --config-dir $dir/configs/ 
fi


if [ $stage -le 11 ]; then
  init_info=$dir/init/info.txt
  if [ ! -f $dir/configs/ref.raw ]; then
    echo "Expected $dir/configs/ref.raw to exist"
    exit
  fi
  mkdir  -p $dir/init
  nnet3-info $dir/configs/ref.raw  > $dir/configs/temp.info 
  model_left_context=$(fgrep 'left-context' $dir/configs/temp.info | awk '{print $2}')
  model_right_context=$(fgrep 'right-context' $dir/configs/temp.info | awk '{print $2}')
  cat >$init_info <<EOF
frame_subsampling_factor $frame_subsampling_factor
langs ${lang_list[@]}
model_left_context $model_left_context
model_right_context $model_right_context
EOF
  rm $dir/configs/temp.info
fi

model_left_context=$(awk '/^model_left_context/ {print $2;}' $dir/init/info.txt)
model_right_context=$(awk '/^model_right_context/ {print $2;}' $dir/init/info.txt)
if [ -z $model_left_context ]; then
  echo "ERROR: Cannot find entry for model_left_context in $dir/init/info.txt"
fi
if [ -z $model_right_context ]; then
  echo "ERROR: Cannot find entry for model_right_context in $dir/init/info.txt"
fi
egs_left_context=$[model_left_context+(frame_subsampling_factor/2)+extra_left_context]
egs_right_context=$[model_right_context+(frame_subsampling_factor/2)+extra_right_context]

if [ $stage -le 12 ]; then
  for lang in ${lang_list[@]};do
    tree_dir=exp/$lang
    ali_dir=exp/$lang/tri3b_ali_sp
      gmm_dir=exp/$lang/tri3b
    cp $tree_dir/tree $dir/${lang}.tree
     echo "$0: creating phone language-model for $lang"
    $train_cmd $dir/den_fsts/log/make_phone_lm_${lang}.log \
      chain-est-phone-lm \
        --num-extra-lm-states=2000 \
        "ark:gunzip -c $ali_dir/ali.*.gz | ali-to-phones $gmm_dir/final.mdl ark:- ark:- |" \
        $dir/den_fsts/${lang}.phone_lm.fst || exit 1;
    echo "$0: creating denominator FST for $lang"
    copy-transition-model $tree_dir/final.mdl $dir/init/${lang}_trans.mdl  || exit 1;
    $train_cmd $dir/den_fsts/log/make_den_fst.log \
      chain-make-den-fst \
        $dir/${lang}.tree \
        $dir/init/${lang}_trans.mdl \
	$dir/den_fsts/${lang}.phone_lm.fst \
        $dir/den_fsts/${lang}.den.fst \
	$dir/den_fsts/${lang}.normalization.fst || exit 1;
  done
fi

if [ $stage -le 13 ]; then
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

if [ $stage -le 14 ]; then
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

if [ $stage -le 15 ]; then
  [ ! -d $dir/egs/misc ] && mkdir  $dir/egs/misc
  echo "$0: Copying den.fst to $dir/egs/misc"
  for lang in ${lang_list[@]};do
    cp $dir/den_fsts/${lang}.*fst $dir/egs/misc/
    cp $dir/init/${lang}_trans.mdl $dir/egs/misc/${lang}.trans_mdl
    [ -L $dir/egs/info_${lang}.txt ] || ln -rs $dir/egs/info.txt $dir/egs/info_${lang}.txt
  done
  echo "$0: Create a dummy transition model that is never used."
  first_lang_name=tunisian_msa
  [[ ! -f $dir/init/default_trans.mdl ]] && ln -r -s $dir/init/${first_lang_name}_trans.mdl $dir/init/default_trans.mdl
fi

if [ $stage -le 16 ]; then
  echo "$0: Preparing initial acoustic model"
  $cuda_cmd $dir/log/init_model.log \
  nnet3-init \
    --srand=${srand} \
    $dir/configs/final.config \
    $dir/init/multi.raw || exit 1
fi

if [ $stage -le 17 ]; then
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

if [ $stage -le 18 ]; then
  echo "$0: Splitting models"
  ivector_dim=$(feat-to-dim scp:exp/tunisian_msa/ivectors_train_sp_hires/ivector_online.scp -) || exit 1;
  feat_dim=$(feat-to-dim scp:data/tunisian_msa/train_sp_hires/feats.scp -)
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

if [ $stage -le 19 ]; then
  # Decode Tunisian MSA
  tree_dir=exp/tunisian_msa
  utils/mkgraph.sh \
    --self-loop-scale 1.0 \
    data/tunisian_msa/lang_test \
    $tree_dir \
    $tree_dir/graph || exit 1;
fi

if [ $stage -le 20 ]; then
  frames_per_chunk=$(echo $chunk_width | cut -d, -f1)
  # Extract high resolution MFCCs from test data
  for f in test; do
    utils/copy_data_dir.sh \
      data/tunisian_msa/$f \
      data/tunisian_msa/${f}_hires || exit 1;
    steps/make_mfcc.sh \
      --cmd "$train_cmd" \
      --mfcc-config conf/mfcc_hires.conf \
      --nj 2 \
      data/tunisian_msa/${f}_hires || exit 1;
    steps/compute_cmvn_stats.sh \
      data/tunisian_msa/${f}_hires || exit 1;
    utils/fix_data_dir.sh data/tunisian_msa/${f}_hires || exit 1;
    # Do the  decoding pass
    steps/online/nnet2/extract_ivectors_online.sh \
      --cmd "$train_cmd" \
      --nj 2 \
      data/tunisian_msa/${f}_hires \
      exp/multi/extractor \
      exp/tunisian_msa/ivectors_${f}_hires || exit 1;

    (
      nspk=$(wc -l <data/tunisian_msa/${f}_hires/spk2utt)
      tree_dir=exp/tunisian_msa || exit 1;
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
        --online-ivector-dir exp/tunisian_msa/ivectors_${f}_hires \
        --post-decode-acwt 10.0 \
        $tree_dir/graph \
        data/tunisian_msa/${f}_hires \
        exp/chain2_multi/tunisian_msa/decode_${f}_hires || exit 1
    )
  done
fi

if [ $stage -le 21 ]; then
  frames_per_chunk=$(echo $chunk_width | cut -d, -f1)
  tree_dir=exp/gale_arabic
  utils/mkgraph.sh \
    --self-loop-scale 1.0 \
    data/gale_arabic/lang_test \
    $tree_dir \
    $tree_dir/graph || exit 1;
  # copy utf8 test directory to a buckwalter test directory
  for f in test; do
    utils/copy_data_dir.sh \
      data/tunisian_msa/${f}_hires \
      data/tunisian_msa/${f}_hires_bw || exit 1;
    # Convert the text file to buckwalter
    cut -d " " -f 1 data/tunisian_msa/${f}_hires/text > ${f}_index.txt
    cut -d " " -f 2- data/tunisian_msa/${f}_hires/text > ${f}_text.txt
    local/buckwalter2unicode.py -r -i ${f}_text.txt -o ${f}_text.bw
    paste -d " " ${f}_index.txt ${f}_text.bw > data/tunisian_msa/${f}_hires_bw/text
    # Decode Tunisian MSA using GALE Arabic
    (
      nspk=$(wc -l <data/tunisian_msa/${f}_hires/spk2utt)
      tree_dir=exp/gale_arabic || exit 1;
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
        --online-ivector-dir exp/tunisian_msa/ivectors_${f}_hires \
        --post-decode-acwt 10.0 \
        $tree_dir/graph \
        data/tunisian_msa/${f}_hires_bw \
        exp/chain2_multi/gale_arabic/decode_${f}_hires_bw || exit 1
    )
  done
fi

if [ $stage -le 22 ]; then
  local/gale_train_lms_utf8.sh \
    ../../gale_arabic/s5d/data/train/text \
    ../../gale_arabic/s5d/data/local/dict/lexicon.txt \
    data/local/lm || exit 1; 
fi

if [ $stage -le 23 ]; then
  local/format_lm_utf8.sh
fi

if [ $stage -le 24 ]; then
  frames_per_chunk=$(echo $chunk_width | cut -d, -f1)
  tree_dir=exp/tunisian_msa
  utils/mkgraph.sh \
    --self-loop-scale 1.0 \
    data/lang_test \
    $tree_dir \
    $tree_dir/graph || exit 1;
  for f in test; do
    # Decode Tunisian MSA using Tunisian MSA with GALE LM
    (
      nspk=$(wc -l <data/tunisian_msa/${f}_hires/spk2utt)
      tree_dir=exp/tunisian_msa || exit 1;
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
        --online-ivector-dir exp/tunisian_msa/ivectors_${f}_hires \
        --post-decode-acwt 10.0 \
        $tree_dir/graph \
        data/tunisian_msa/${f}_hires \
        exp/chain2_multi/tunisian_msa/decode_${f}_hires_utf8 || exit 1
    )
  done
fi

#   Run a decoder test on recordings in the following directory:
datadir=/mnt/corpora/Libyan_msa_arl
#speakers=(adel anwar bubaker hisham mukhtar redha srj yousef)
speakers=(adel bubaker hisham mukhtar redha yousef)

# Set variables
acoustic_scale=1.0 #  Scaling factor for acoustic log-likelihoods (float, default = 0.1)
add_pitch=false  #  Append pitch features to raw MFCC/PLP/filterbank features [but not for iVector extraction] (bool, default = false)
beam=16.0 # Decoding beam.  Larger->slower, more accurate. (float, default = 16)
beam_delta=0.5 # Increment used in decoding-- this parameter is obscure and relates to a speedup in the way the max-active constraint is applied.  Larger is more accurate. (float, default = 0.5)
chunk_length=0.18 # Length of chunk size in seconds, that we process.  Set to <= 0 to use all input in one chunk. (float, default = 0.18)
computation_debug=false # If true, turn on debug for the neural net computation (very verbose!) Will be turned on regardless if --verbose >= 5 (bool, default = false)
cmvn_config= # Configuration file for online cmvn features (e.g. conf/online_cmvn.conf). Controls features on nnet3 input (not ivector features). If not set, the OnlineCmvn is disabled. (string, default = "")
debug_computation=true # If true, turn on debug for the actual computation (very verbose!) (bool, default = false)
delta=0.000976562 # Tolerance used in determinization (float, default = 0.000976562)
determinize_lattice=true # If true, determinize the lattice (lattice-determinization, keeping only best pdf-sequence for each word-sequence). (bool, default = true)
do_endpointing=false # If true, apply endpoint detection (bool, default = false)
egs_extra_left_context=5
egs_extra_right_context=5
endpoint_rule1_max_relative_cost=inf # This endpointing rule requires relative-cost of final-states to be <= this value (describes how good the probability of final-states is). (float, default = inf)
endpoint_rule1_min_trailing_silence=5 # This endpointing rule requires duration of trailing silence(in seconds) to be >= this value. (float, default = 5)
endpoint_rule1_min_utterance_length=1.0 # This endpointing rule requires utterance-length (in seconds) to be >= this value. (float, default = 0)
endpoint_rule1_must_contain_nonsilence=true # If true, for this endpointing rule to apply there must be nonsilence in the best-path traceback. (bool, default = false)
endpoint_rule2_max_relative_cost=2 # This endpointing rule requires relative-cost of final-states to be <= this value (describes how good the probability of final-states is). (float, default = 2)
endpoint_rule2_min_trailing_silence=0.5 # This endpointing rule requires duration of trailing silence(in seconds) to be >= this value. (float, default = 0.5)
endpoint_rule2_min_utterance_length=2 # This endpointing rule requires utterance-length (in seconds) to be >= this value. (float, default = 0)
endpoint_rule2_must_contain_nonsilence=true # If true, for this endpointing rule to apply there must be nonsilence in the best-path traceback. (bool, default = true)
endpoint_rule3_max_relative_cost=8 # This endpointing rule requires relative-cost of final-states to be <= this value (describes how good the probability of final-states is). (float, default = 8)
endpoint_rule3_min_trailing_silence=1 # This endpointing rule requires duration of trailing silence(in seconds) to be >= this value. (float, default = 1)
endpoint_rule3_min_utterance_length=2 # This endpointing rule requires utterance-length (in seconds) to be >= this value. (float, default = 0)
endpoint_rule3_must_contain_nonsilence=true # If true, for this endpointing rule to apply there must be nonsilence in the best-path traceback. (bool, default = true)
endpoint_rule4_max_relative_cost=inf # This endpointing rule requires relative-cost of final-states to be <= this value (describes how good the probability of final-states is). (float, default = inf)
endpoint_rule4_min_trailing_silence=2 # This endpointing rule requires duration of trailing silence(in seconds) to be >= this value. (float, default = 2)
endpoint_rule4_min_utterance_length=0 # This endpointing rule requires utterance-length (in seconds) to be >= this value. (float, default = 0)
endpoint_rule4_must_contain_nonsilence=true # If true, for this endpointing rule to apply there must be nonsilence in the best-path traceback. (bool, default = true)
endpoint_rule5_max_relative_cost=inf # This endpointing rule requires relative-cost of final-states to be <= this value (describes how good the probability of final-states is). (float, default = inf)
endpoint_rule5_min_trailing_silence=5 # This endpointing rule requires duration of trailing silence(in seconds) to be >= this value. (float, default = 0)
endpoint_rule5_min_utterance_length=20 # This endpointing rule requires utterance-length (in seconds) to be >= this value. (float, default = 20)
endpoint_rule5_must_contain_nonsilence=true # If true, for this endpointing rule to apply there must be nonsilence in the best-path traceback. (bool, default = false)
endpoint_silence_phones="1:2:3:4:5:6:7:8:9:10" # List of phones that are considered to be silence phones by the endpointing code. (string, default = "")
extra_left_context_initial=0
fbank_config="" # Configuration file for filterbank features (e.g. conf/fbank.conf) (string, default = "")
feature_type=mfcc # Base feature type [mfcc, plp, fbank] (string, default = "mfcc")
frame_subsampling_factor=3 # Required if the frame-rate of the output (e.g. in 'chain' models) is less than the frame-rate of the original alignment. (int, default = 1)
frames_per_chunk=20 # Number of frames in each chunk that is separately evaluated by the neural net.  Measured before any subsampling, if the --frame-subsampling-factor options is used (i.e. counts input frames.  This is only advisory (may be rounded up if needed. (int, default = 20)
global_cmvn_stats="" # filename with global stats for OnlineCmvn for features on nnet3 input (not ivector features) (string, default = "")
hash_ratio=2 # Setting used in decoder to control hash behavior (float, default = 2)
ivector_extraction_config= # Configuration file for online iVector extraction, see class OnlineIvectorExtractionConfig in the code (string, default = "")
ivector_silence_weighting_silence_phones="" # (RE weighting in iVector estimation for online decoding) List of integer ids of silence phones, separated by colons (or commas). Data that (according to the traceback of the decoder) corresponds to these phones will be downweighted by --silence-weight. (string, default = "")
ivector_silence_weighting_silence_weight=1 # (RE weighting in iVector estimation for online decoding) Weighting factor for frames that the decoder trace-back identifies as silence; only relevant if the --silence-phones option is set. (float, default = 1)--ivector-silence-weighting.silence-weight : (RE weighting in iVector estimation for online decoding) Weighting factor for frames that the decoder trace-back identifies as silence; only relevant if the --silence-phones option is set. (float, default = 1)
lattice_beam=10.0 # Lattice generation beam. Larger->slower, and deeper lattices (float, default <= 10)
max_active=2147483647 # Decoder max active states. Larger->slower; more accurate (int, default = 2147483647)
max_mem=500000000 # Maximum approximate memory usage in determinization (real usage might be many times this). (int, default = 50000000)
mfcc_config= # Configuration file for MFCC features (e.g. conf/mfcc.conf) (string, default = "")
min_active=200 # Decoder minimum #active states. (int, default = 200)
minimize=false # If true, push and minimize after determinization. (bool, default = false)
num_threads_startup=8 # Number of threads used when initializing iVector extractor. (int, default = 8)
online=true # You can set this to false to disable online iVector estimation and have all the data for each utterance used, even at utterance start. This is useful where you just want the best results and don't care about online operation. Setting this to false has the same effect as setting --use-most-recent-ivector=true and --greedy-ivector-extractor=true in the file given to --ivector-extraction-config, and --chunk-length=-1. (bool, default = true)
online_pitch_config="" # Configuration file for online pitch features, if --add-pitch=true (e.g. conf/online_pitch.conf) (string, default = "")
optimization_allocate_from_other=true # Instead of deleting a matrix of a given size and then allocating a matrix of the same size, allow re_use of that memory (bool, default = true)
optimization_allow_left_merge=true # Set to false to disable left_merging of variables in remove_assignments (obscure option) (bool, default = true)
optimization_allow_right_merge=true # Set to false to disable right_merging of variables in remove_assignments (obscure option) (bool, default = true)
optimization_backprop_in_place=true # Set to false to disable optimization that allows in_place backprop (bool, default = true)
optimization_consolidate_model_update=true # Set to false to disable optimization that consolidates the model_update phase of backprop (e.g. for recurrent architectures (bool, default = true)
optimization_convert_addition=true # Set to false to disable the optimization that converts Add commands into Copy commands wherever possible. (bool, default = true)
optimization_extend_matrices=true # This optimization can reduce memory requirements for TDNNs when applied together with __convert_addition=true (bool, default = true)
optimization_initialize_undefined=true # Set to false to disable optimization that avoids redundant zeroing (bool, default = true)
optimization_max_deriv_time=2147483647 # You can set this to the maximum t value that you want derivatives to be computed at when updating the model. This is an optimization that saves time in the backprop phase for recurrent frameworks (int, default = 2147483647)
optimization_max_deriv_time_relative=2147483647 # An alternative mechanism for setting the __max_deriv_time, suitable for situations where the length of the egs is variable. If set, it is equivalent to setting the __max_deriv_time to this value plus the largest 't' value in any 'output' node of the computation request. (int, default = 2147483647)
optimization_memory_compression_level=1 # This is only relevant to training, not decoding. Set this to 0,1,2; higher levels are more aggressive at reducing memory by compressing quantities needed for backprop, potentially at the expense of speed and the accuracy of derivatives. 0 means no compression at all; 1 means compression that shouldn't affect results at all. (int, default = 1)
optimization_min_deriv_time=-2147483648 # You can set this to the minimum t value that you want derivatives to be computed at when updating the model. This is an optimization that saves time in the backprop phase for recurrent frameworks (int, default = _2147483648)
optimization_move_sizing_commands=true # Set to false to disable optimization that moves matrix allocation and deallocation commands to conserve memory. (bool, default = true)
optimization_optimize=false # Set=true this to false to turn off all optimizations (bool, default = true)
optimization_optimize_row_ops=true # Set to false to disable certain optimizations that act on operations of type *Row*. (bool, default = true)
optimization_propagate_in_place=true # Set to false to disable optimization that allows in_place propagation (bool, default = true)
optimization_remove_assignments=true # Set to false to disable optimization that removes redundant assignments (bool, default = true)
optimization_snip_row_ops=true # Set this to false to disable an optimization that reduces the size of certain per_row operations (bool, default = true)
optimization_split_row_ops=true # Set to false to disable an optimization that may replace some operations of type kCopyRowsMulti or kAddRowsMulti with up to two simpler operations. (bool, default = true)
phone_determinize=true # If true, do an initial pass of determinization on both phones and words (see also --word-determinize) (bool, default = true)
plp_config="" # Configuration file for PLP features (e.g. conf/plp.conf) (string, default = "")
prune_interval=25 # Interval=25 (in frames) at which to prune tokens (int, default = 25)
word_determinize=true # If true, do a second pass of determinization on words only (see also --phone-determinize) (bool, default = true)
lat_acoustic_scale=1.0 #acoustic-scale            : Scaling factor for acoustic likelihoods (float, default = 1)
acoustic2lm_scale=0.0 # Add this times original acoustic costs to LM costs (float, default = 0)
inv_acoustic_scale=1.0 # An alternative way of setting the acoustic scale: you can set its inverse. (float, default =1)
lm_scale=0.1 # Scaling factor for graph/lm costs (float, default = 1)
lm2acoustic_scale=0.0 #        : Add this times original LM costs to acoustic costs (float, default = 0)
write_compact=true # If true, write in normal (compact) form. (bool, default = true)
# Finished setting variables and parameters
src=$(pwd)
# Set location of local config files
ivector_extraction_config=exp/chain/tdnn1a_sp_online/conf/ivector_extractor.conf
mfcc_config=conf/mfcc_hires.conf

if [ $stage -le 0 ]; then
  for s in ${speakers[@]}; do
  echo "Making kaldi directory for $s."
  mkdir -vp data/$s
  find $datadir -type f -name "*${s}*.wav" | sort > \
    data/$s/recordings_wav.txt

  local/test_recordings_make_lists.pl \
    $datadir/$s/data/transcripts/recordings/${s}_recordings.tsv $s libyan \
    || exit 1;
  utils/utt2spk_to_spk2utt.pl data/$s/utt2spk | sort > \
      data/$s/spk2utt || exit 1;
  done
fi

# Extract Mel Frequency Cepstral Coefficients from input recordings
if [ $stage -le 1 ]; then
  for s in ${speakers[@]}; do
  echo "Extract features for $s."
    steps/make_mfcc.sh data/$s
  done
fi

# Combin directories into 1 test directory. This is probably unnecessary.
if [ $stage -le 2 ]; then
  utils/combine_data.sh data/test data/adel data/anwar data/bubaker data/hisham \
    data/mukhtar data/redha data/srj data/yousef
fi

# Run the kaldi decoder
if [ $stage -le 3 ]; then
  if [ -d $src/decode_online ]; then
    echo "Directory $src/decode_online already exists."
    echo "rm -Rf $src/decode_online"
    exit 1
  fi
  for s in ${speakers[@]}; do
    echo "Decoding $s."
    mkdir -p $src/decode_online/$s/log
    run.pl $src/decode_online/$s/log/decode.log \
      online2-wav-nnet3-latgen-faster \
        --acoustic-scale=$acoustic_scale \
        --add-pitch=$add_pitch \
        --beam=$beam \
        --beam-delta=$beam_delta \
	--chunk-length=$chunk_length \
        --computation.debug=$computation_debug \
        --config=$src/conf/online.conf \
	--debug-computation=$debug_computation \
	--delta=$delta \
	--determinize-lattice=$determinize_lattice \
        --do-endpointing=$do_endpointing \
        --endpoint.rule1.max-relative-cost=$endpoint_rule1_max_relative_cost \
        --endpoint.rule1.min-trailing-silence=$endpoint_rule1_min_trailing_silence \
        --endpoint.rule1.min-utterance-length=$endpoint_rule1_min_utterance_length \
        --endpoint.rule1.must-contain-nonsilence=$endpoint_rule1_must_contain_nonsilence \
        --endpoint.rule2.max-relative-cost=$endpoint_rule2_max_relative_cost \
        --endpoint.rule2.min-trailing-silence=$endpoint_rule2_min_trailing_silence \
        --endpoint.rule2.min-utterance-length=$endpoint_rule2_min_utterance_length \
        --endpoint.rule2.must-contain-nonsilence=$endpoint_rule2_must_contain_nonsilence \
        --endpoint.rule3.max-relative-cost=$endpoint_rule3_max_relative_cost \
        --endpoint.rule3.min-trailing-silence=$endpoint_rule3_min_trailing_silence \
        --endpoint.rule3.min-utterance-length=$endpoint_rule3_min_utterance_length \
        --endpoint.rule3.must-contain-nonsilence=$endpoint_rule3_must_contain_nonsilence \
        --endpoint.rule4.max-relative-cost=$endpoint_rule4_max_relative_cost \
        --endpoint.rule4.min-trailing-silence=$endpoint_rule4_min_trailing_silence \
        --endpoint.rule4.min-utterance-length=$endpoint_rule4_min_utterance_length \
        --endpoint.rule4.must-contain-nonsilence=$endpoint_rule4_must_contain_nonsilence \
        --endpoint.rule5.max-relative-cost=$endpoint_rule5_max_relative_cost \
        --endpoint.rule5.min-trailing-silence=$endpoint_rule5_min_trailing_silence \
        --endpoint.rule5.min-utterance-length=$endpoint_rule5_min_utterance_length \
        --endpoint.rule5.must-contain-nonsilence=$endpoint_rule5_must_contain_nonsilence \
        --endpoint.silence-phones=$endpoint_silence_phones \
        --extra-left-context-initial=$extra_left_context_initial \
        --fbank-config=$fbank_config \
        --feature-type=$feature_type \
        --frame-subsampling-factor=$frame_subsampling_factor \
        --frames-per-chunk=$frames_per_chunk \
        --global-cmvn-stats=$global_cmvn_stats \
        --hash-ratio=$hash_ratio \
        --ivector-extraction-config=$ivector_extraction_config \
        --ivector-silence-weighting.silence-phones=$ivector_silence_weighting_silence_phones \
        --ivector-silence-weighting.silence-weight=$ivector_silence_weighting_silence_weight \
        --lattice-beam=$lattice_beam \
        --max-active=$max_active \
        --max-mem=$max_mem \
        --mfcc-config=$mfcc_config \
        --min-active=$min_active \
        --minimize=$minimize \
        --num-threads-startup=$num_threads_startup \
        --online=$online \
        --word-determinize=$word_determinize \
        --word-symbol-table=exp/chain/tree_sp/graph/words.txt \
        exp/chain/tdnn1a_sp_online/final.mdl \
        exp/chain/tree_sp/graph/HCLG.fst \
        ark:data/$s/spk2utt \
        "ark,s,cs:wav-copy scp,p:data/$s/wav.scp ark:- |" \
        "ark:|lattice-scale \
          --acoustic-scale=$lat_acoustic_scale \
          --acoustic2lm-scale=$acoustic2lm_scale          \
          --inv-acoustic-scale=$inv_acoustic_scale \
          --lm-scale=$lm_scale \
          --lm2acoustic-scale=$lm2acoustic_scale \
          --write-compact=$write_compact              \
        ark:- ark,t:- > $src/decode_online/$s/lat.txt"
  done
fi

# Concatenate output lattices
if [ $stage -le 4 ]; then
  for s in ${speakers[@]}; do
    echo "Concatenating lattice for $s."
    cat $src/decode_online/$s/lat.txt >> $src/decode_online/lat.1
  done
  # Remove old zip lat file
  if [ -f $src/decode_online/lat.1.gz ]; then
    rm $src/decode_online/lat.1.gz
  fi
  # zip new lat file
  gzip $src/decode_online/lat.1
fi

# Run scoring
if [ $stage -le 5 ]; then
    ./steps/scoring/score_kaldi_wer.sh \
      --cmd run.pl \
      data/test \
      exp/chain/tree_sp/graph \
    $src/decode_online
fi

# Note: we add frame_subsampling_factor/2 so that we can support the frame
# shifting that's done during training, so if frame-subsampling-factor=3, we
# train on the same egs with the input shifted by -1,0,1 frames.  This is done
# via the --frame-shift option to nnet3-chain-copy-egs in the script.
model_left_context=50
model_right_context=0
egs_left_context=$[model_left_context+(frame_subsampling_factor/2)+egs_extra_left_context]
egs_right_context=$[model_right_context+(frame_subsampling_factor/2)+egs_extra_right_context]

if [ $stage -le 6 ]; then
  for s in ${speakers[@]}; do
    steps/online/nnet2/extract_ivectors_online.sh \
      --cmd run.pl \
      --nj 1 \
      data/$s \
      $src/ivector_extractor \
      $src/decode_offline/ivectors_${s}

    steps/nnet3/decode.sh \
      --acwt 1.0 \
      --cmd run.pl  \
      --extra-left-context $egs_left_context \
      --extra-left-context-initial 0 \
      --extra-right-context $egs_right_context \
      --extra-right-context-final 0 \
      --frames-per-chunk $frames_per_chunk \
      --nj 1 \
      --num-threads 4 \
      --online-ivector-dir $src/decode_offline/ivectors_${s} \
      --post-decode-acwt 10.0 \
      $src \
      data/$s \
      $src/decode_offline/$s || exit 1
  done
fi
exit 0

        --optimization.propagate-in-place=
        --optimization.remove-assignments=
        --optimization.snip-row-ops=
        --optimization.split-row-ops=
        --phone-determinize=
        --plp-config=
        --prune-interval=

        --optimization.allocate-from-other=$optimization_allocate_from_other \
        --optimization.allow-left-merge=$optimization_allow_left_merge \
        --optimization.allow-right-merge=$optimization_allow_right_merge \
        --optimization.backprop-in-place=$optimization_backprop_in_place \
        --optimization.consolidate-model-update=$optimization_consolidate_model_update \
        --optimization.convert-addition=$optimization_convert_addition \
        --optimization-extend-matrices=$optimization_extend_matrices \
        --optimization.initialize-undefined=$optimization_initialize_undefined \
        --optimization.max-deriv-time=$optimization_max_deriv_time \
        --optimization.max-deriv-time-relative=$optimization_max_deriv_time_relative \
        --optimization.memory-compression-level=$optimization_memory_compression_level \
        --optimization.min-deriv-time=$optimization_min_deriv_time \
        --optimization.move-sizing-commands=$optimization_move_sizing_commands \
        --optimization.optimize=$optimization_optimize \
        --optimization.optimize-row-ops=$optimization_optimize_row_ops \

nnet3-latgen-faster-parallel \
  --num-threads=4 \
  --online-ivectors=scp:exp/multi_tamsa_librispeech_tamsa/decode_offline/ivectors_adel/ivector_online.scp \
  --online-ivector-period=10 \
  --frames-per-chunk=20 \
  --extra-left-context=76 \
  --extra-right-context=26 \
  --extra-left-context-initial=0 \
  --extra-right-context-final=0 \
  --minimize=false \
  --max-active=7000 \
  --min-active=200 \
  --beam=15.0 \
  --lattice-beam=8.0 \
  --acoustic-scale=1.0 \
  --allow-partial=true \
  --word-symbol-table=exp/multi_tamsa_librispeech_tamsa/words.txt \
  exp/multi_tamsa_librispeech_tamsa/decode_offline/final.mdl \
  exp/multi_tamsa_librispeech_tamsa/HCLG.fst \
  "ark,s,cs:apply-cmvn --norm-means=false --norm-vars=false --utt2spk=ark:data/adel/split1/1/utt2spk scp:data/adel/split1/1/cmvn.scp scp:data/adel/split1/1/feats.scp ark:- |" "ark:|lattice-scale --acoustic-scale=10.0 ark:- ark:- | gzip -c >exp/multi_tamsa_librispeech_tamsa/decode_offline/adel/lat.1.gz"
