#!/usr/bin/env bash

# chain2 recipe for  Tunisian MSA, globalphone tunisian,  gale_arabic, MSA MFLTS and Lexicon and LM from GALE Arabic.

# Copyright 2016 Pegah Ghahremani
# Copyright 2020 Srikanth Madikeri (Idiap Research Institute)

# Train a multilingual LF-MMI system with a multi-task training setup.
# This script assumes the following 4 recipes have been run:
# - ../s5k/run.sh 
# ../../globalphone_tunisian/s5/run.sh
# ../../gale_arabic/s5d/run.sh
# ../../msa_mflts/s5/run.sh
set -e -o pipefail

# language dependent variable settings
dir=exp/chain2_multi
# the order of the elements in the following listss is important
egs_dir_list="$dir/tunisian_msa_processed_egs $dir/globalphone_tunisian_processed_egs $dir/gale_arabic_processed_egs $dir/msa_mflts_processed_egs"
# the following variable is hard coded in the local/combine_egs.sh leaving it here for now
lang2weight="0.25,0.25,0.25,0.25"
#
lang_list=(tunisian_msa globalphone_tunisian gale_arabic msa_mflts)
num_langs=4

# Start setting other variables
arl_lm_data_path=/mnt/corpora/ultra/arabic_lm_text/ar
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
  lexicon=../../gale_arabic/s5d/data/local/dict/lexicon.txt
lm_dir=data/local/lm
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
    [ -L lang ] || ln -s ../../../s5k/data/lang ./;
    # link the train directory
    [ -L train ] || ln -s ../../../s5k/data/train ./;
    # link the devtest directory
    [ -L devtest ] || ln -s ../../../s5k/data/devtest ./;
    # link the test directory
    [ -L test ] || ln -s ../../../s5k/data/test ./;
    # link the lang_test directory
    [ -L lang_test ] || ln -s ../../../s5k/data/lang_test ./;
  )

  # link exp directories from tunisian_msa
  (
    echo "Link exp directories from tunisian_msa."
    [ -d exp/tunisian_msa ] || mkdir -p exp/tunisian_msa;
    cd exp/tunisian_msa
    # link the tri3b directory
    [ -L tri3b ] || ln -s ../../../s5k/exp/tri3b ./;
    # link the tri3b_ali
    [ -L tri3b_ali ] || ln -s ../../../s5k/exp/tri3b_ali ./;
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
  # Extract high resolution MFCCs from dev and test data
  for f in devtest test; do
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
  for f in devtest test; do
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
    $lexicon \
    $lm_dir || exit 1; 
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
  for f in devtest test; do
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

if [ $stage -le 25 ]; then
  # Get the ARL LM training text
  # The data is located under /mnt/corpora/ultra/arabic_lm_text/ar
  # The data is written to data/local/lm/training_arl_text_utf8.txt
    [ ! -d $lm_dir ] || rm -Rf $lm_dir;
  mkdir -p $lm_dir
  # get the ARL lm training text
  for f in fm5.0_cleaned_ZA_ar fm6.0_cleaned_ZA_ar fm6.22_cleaned_ZA_ar FM7-8_cleaned_ZA_ar mflts_msa_ar MNSTC-I_cleaned_ZA_ar; do
    cat $arl_lm_data_path/$f.txt >> data/local/lm/training_arl_text_utf8.txt
  done
  # get rid of the carriage returns
  $(dos2unix $lm_dir/training_arl_text_utf8.txt)
  gale_training_text=../../gale_arabic/s5d/data/train/text
  [ -f $gale_training_text ] || echo "$0: No such file $gale_training_text"
  heldout_sent=10000
  cut -d' ' -f2- $gale_training_text   > $lm_dir/train.gale_bw
  cut -d' ' -f2- $gale_training_text | tail -n +$heldout_sent  > $lm_dir/train_gale_bw
  cut -d' ' -f2- $gale_training_text | head -n $heldout_sent > $lm_dir/heldout_gale_bw
fi

if [ $stage -le 26 ]; then
  echo "$0: Converting the heldout to utf8."
  local/buckwalter2unicode.py \
    -i $lm_dir/heldout_gale_bw \
    -o $lm_dir/heldout_gale_utf8.txt
fi

if [ $stage -le 27 ]; then
  echo "$0: Get GALE bw wordlist."
  [ -f $lexicon ] || echo "$0: No such file $lexicon"
  cut -d ' ' -f 1 $lexicon > $lm_dir/wordlist_gale_bw
  echo "$0: Convert the wordlist to utf8."
  local/buckwalter2unicode.py \
    -i $lm_dir/wordlist_gale_bw \
    -o $lm_dir/wordlist_gale_utf8.txt
  # convert the training text to utf8
  local/buckwalter2unicode.py \
    -i $lm_dir/train_gale_bw \
    -o $lm_dir/train_gale_utf8.txt
  # concatenate the GALE and ARL training text
  cat $lm_dir/train_gale_utf8.txt $lm_dir/training_arl_text_utf8.txt > $lm_dir/train_gale_arl_utf8.txt
  gzip $lm_dir/train_gale_arl_utf8.txt
  # get the wordlist from GALE and ARL lm training text
  cat $lm_dir/train_gale_arl_utf8.txt | tr " " "\n" | sort -u > $lm_dir/wordlist_gale_arl_utf8.txt
fi

loc=$(which ngram-count);
if [ -z $loc ]; then
  if uname -a | grep 64 >/dev/null; then # some kind of 64 bit...
    sdir=$(pwd)/../../../tools/srilm/bin/i686-m64 
  else
    sdir=$(pwd)/../../../tools/srilm/bin/i686
  fi
  if [ -f $sdir/ngram-count ]; then
    echo Using SRILM tools from $sdir
    export PATH=$PATH:$sdir
  else
    echo You appear to not have SRILM tools installed, either on your path,
    echo or installed in $sdir.  See tools/install_srilm.sh for installation
    echo instructions.
    exit 1
  fi
fi

export LC_ALL=C 

if [ $stage -le 28 ]; then
  echo "$0: training tri-gram lm"
  smoothing="kn"
  ngram-count \
    -text $lm_dir/train_gale_arl_utf8.txt.gz \
    -order 3 \
    -limit-vocab \
    -vocab $lm_dir/wordlist_gale_arl_utf8.txt \
    -unk -map-unk "<UNK>" \
    -${smoothing}discount -interpolate -lm \
    $lm_dir/gale_arl.o3g.${smoothing}_utf8.gz
  echo "PPL for GALE ARL Arabic trigram LM:"
  ngram \
    -unk \
    -lm $lm_dir/gale_arl.o3g.${smoothing}_utf8.gz \
    -ppl $lm_dir/heldout_gale_utf8.txt
  ngram \
    -unk \
    -lm \
    $lm_dir/gale_arl.o3g.${smoothing}_utf8.gz \
    -ppl $lm_dir/heldout_utf8.txt \
    -debug 2 >& $lm_dir/3gram.${smoothing}_gale_arl_utf8.ppl2
  # 4gram language model
  echo "$0: training 4-gram GALE ARL lm"
  ngram-count \
    -text $lm_dir/train_gale_arl_utf8.txt.gz \
    -order 4 \
    -limit-vocab \
    -vocab $lm_dir/wordlist_gale_utf8.txt \
    -unk \
    -map-unk "<UNK>" \
    -${smoothing}discount \
    -interpolate \
    -lm $lm_dir/gale_arl.o4g.${smoothing}_utf8.gz
  echo "PPL for GALE ARL Arabic 4gram LM:"
  ngram \
    -unk \
    -lm $lm_dir/gale_arl.o4g.${smoothing}_utf8.gz \
    -ppl $lm_dir/heldout_gale_utf8.txt
  ngram \
    -unk \
    -lm $lm_dir/gale_arl.o4g.${smoothing}_utf8.gz \
    -ppl $lm_dir/heldout_gale_utf8.txt \
    -debug 2 >& $lm_dir/4gram.${smoothing}_gale_arl_utf8.ppl2
fi

if [ $stage -le 28 ]; then
  local/format_lm_gale_arl.sh
fi

if [ $stage -le 29 ]; then
  frames_per_chunk=$(echo $chunk_width | cut -d, -f1)
  tree_dir=exp/tunisian_msa
  utils/mkgraph.sh \
    --self-loop-scale 1.0 \
    data/lang_test_gale_arl \
    $tree_dir \
    $tree_dir/graph_gale_arl || exit 1;
  for f in devtest test; do
    # Decode Tunisian MSA using Tunisian MSA with GALE ARL LM and GALE lexicon
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
        $tree_dir/graph_gale_arl \
        data/tunisian_msa/${f}_hires \
        exp/chain2_multi/tunisian_msa/decode_${f}_hires_gale_arl_utf8 || exit 1
    )
  done
fi
