#!/bin/bash
# chain2 recipe for monolingual systems for BABEL
# Copyright 2016 Pegah Ghahremani
# Copyright 2020 Srikanth Madikeri (Idiap Research Institute)

# Train a multilingual LF-MMI system with a multi-task training setup.

set -e -o pipefail

# Start setting variables
alidir=tri3b_ali
boost_sil=1.0 # Factor by which to boost silence likelihoods in alignment
chunk_width=150
cmd=run.pl
common_egs_dir=  # you can set this to use previously dumped egs.
decode_lang_list=(mini_librispeech)
decode_stage=-10
dir=exp/chain2_multi
extra_left_context=50
extra_right_context=0
final_effective_lrate=0.0001
frame_subsampling_factor=3
get_egs_stage=-10
global_extractor=exp/multi
gmm=tri3b  # the gmm for the target data
initial_effective_lrate=0.001
label_delay=5
lang2weight="0.2,0.8"
lang_list=(mini_librispeech heroico)
langdir=data/lang
lda_mllt_lang=mini_librispeech
max_param_change=2.0
megs_dir=
nj=30
numGaussUBM=512
num_jobs_final=1
num_jobs_initial=1
num_threads_ubm=1
remove_egs=false
srand=-1
stage=-1
suffix=_sp
tdnn_affix=  #affix for TDNN directory, e.g. "a" or "b", in case we change the configuration.
train_set=train
train_stage=-10
tree_affix=  # affix for tree directory, e.g. "a" or "b", in case we change the configuration.
xent_regularize=0.01
# done setting variables

. ./path.sh
. ./cmd.sh
. ./utils/parse_options.sh

echo "$0 $@"  # Print the command line for logging
if ! cuda-compiled; then
  cat <<EOF && exit 1
This script is intended to be used with GPUs but you have not compiled Kaldi with CUDA
If you want to use GPUs (and have them), go to src/, and configure and make on a machine
where "nvcc" is installed.
EOF
fi
# Copy data directories from heroico
if [ $stage -le 0 ]; then
  (
    echo "$0: Copy data directories from heroico."
    [ -d data/heroico ] || mkdir -p data/heroico;
    cd data/heroico
    # Copy the lang directory
    [ -d lang ] || cp -R ../../../../heroico/s5/data/lang ./;
    # Copy the train directory
    [ -d train ] || cp -R ../../../../heroico/s5/data/train ./;
  )

  # Copy exp directories from heroico
  (
    echo "Copy exp directories from heroico."
    [ -d exp/heroico ] || mkdir -p exp/heroico;
    cd exp/heroico
    # Copy the tri3b directory
    [ -d tri3b ] || cp -R ../../../../heroico/s5/exp/tri3b ./;
    # Copy the tri3b_ali
    [ -d tri3b_ali ] || cp -R ../../../../heroico/s5/exp/tri3b_ali ./;
  )

  # Copy mini_librispeech data directories
  (
    echo "Copy data directories from mini_librispeech."
    [ -d data/mini_librispeech ] || mkdir -p data/mini_librispeech;
    cd data/mini_librispeech
    [ -d lang ] || cp -R ../../../s5/data/lang ./;
    [ -d lang_nosp_test_tgsmall ] || cp -R ../../../s5/data/lang_nosp_test_tgsmall ./;
    [ -d train ] || cp -R ../../../s5/data/train_clean_5 ./train;
    [ -d dev_clean_2 ] || cp -R ../../../s5/data/dev_clean_2 ./train;
  )

  # Copy mini_librispeech exp directories
  (
    echo "Copy mini_librispeech exp directories."
    [ -d exp/mini_librispeech ] || mkdir -p exp/mini_librispeech;
    cd exp/mini_librispeech
    [ -d tri3b ] || cp -R ../../../s5/exp/tri3b ./;
    [ -d tri3b_ali ] || cp -R ../../../s5/exp/tri3b_ali_train_clean_5 ./tri3b_ali;
  )
fi

num_langs=${#lang_list[@]}
for lang_index in $(seq 0 $[$num_langs-1]); do
  for f in data/${lang_list[$lang_index]}/train/{feats.scp,text} exp/${lang_list[$lang_index]}/$alidir/ali.1.gz exp/${lang_list[$lang_index]}/$alidir/tree; do
    [ ! -f $f ] && echo "$0: no such file $f" && exit 1;
  done
done

if [ $stage -le 1 ]; then
  for lang in mini_librispeech heroico; do
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
  for lang in mini_librispeech heroico;do
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
  for lang in mini_librispeech heroico; do
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
for lang in mini_librispeech heroico; do
  multi_lores_data_dirs[${lang}]=data/$lang/train_sp
  multi_data_dirs[${lang}]=data/$lang/train_sp_hires
  multi_egs_dirs[${lang}]=exp/$lang/egs
  multi_ali_dirs[${lang}]=exp/$lang
  multi_ivector_dirs[${lang}]=exp/$lang/ivectors_train_sp_hires
  multi_ali_treedirs[${lang}]=exp/$lang/tree_affix}
  multi_ali_latdirs[${lang}]=exp/$lang/chain/tri3b_train_sp_lats
  multi_lang[${lang}]=data/$lang/lang
  multi_lfmmi_lang[${lang}]=data/$lang/lang_chain
  multi_gmm_dir[${lang}]=exp/$lang/tri3b
  multi_chain_dir[${lang}]=exp/$lang/chain/$dir_basename
done

ivector_dim=$(feat-to-dim scp:exp/mini_librispeech/ivectors_train_sp_hires/ivector_online.scp -) || exit 1;
feat_dim=`feat-to-dim scp:data/mini_librispeech/train_sp_hires/feats.scp -`

if [ $stage -le 7 ]; then
  for lang in mini_librispeech heroico;do
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
  for lang in mini_librispeech heroico;do
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
  for lang in mini_librispeech heroico;do
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
  dummy_tree_dir=exp/mini_librispeech
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
  for lang in mini_librispeech heroico;do
    tree_dir=exp/$lang
    num_targets=$(tree-info $tree_dir/tree 2>/dev/null | grep num-pdfs | awk '{print $2}') || exit 1;

    #echo "relu-renorm-layer name=prefinal-affine-lang-${lang_name} input=tdnn7 dim=450 target-rms=0.5"
    echo "output-layer name=output-${lang} dim=$num_targets input=tdnn7  max-change=1.5 include-log-softmax=false"
    echo "output-layer name=output-${lang}-xent input=tdnn7 dim=$num_targets  learning-rate-factor=$learning_rate_factor max-change=1.5"
  done >> $dir/configs/network.xconfig

  lang_name=mini_librispeech
  steps/nnet3/xconfig_to_configs.py --xconfig-file $dir/configs/network.xconfig \
    --config-dir $dir/configs/ 
fi

init_info=$dir/init/info.txt
if [ $stage -le 11 ]; then
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

if [ $stage -le 13 ]; then
  for lang_index in `seq 0 $[$num_langs-1]`;do
      lang_name=${lang_list[$lang_index]}
      tree_dir=${multi_ali_treedirs[$lang_index]}
      ali_dir=${multi_ali_dirs[$lang_index]}
      gmm_dir=${multi_gmm_dir[$lang_index]}

      cp $tree_dir/tree $dir/${lang_name}.tree
      echo "$0: creating phone language-model for $lang_name"
      $train_cmd $dir/den_fsts/log/make_phone_lm_${lang_name}.log \
        chain-est-phone-lm --num-extra-lm-states=2000 \
           "ark:gunzip -c $ali_dir/ali.*.gz | ali-to-phones $gmm_dir/final.mdl ark:- ark:- |" \
           $dir/den_fsts/${lang_name}.phone_lm.fst || exit 1
      echo "$0: creating denominator FST for $lang_name"
      copy-transition-model $tree_dir/final.mdl $dir/init/${lang_name}_trans.mdl  || exit 1 
      $train_cmd $dir/den_fsts/log/make_den_fst.log \
         chain-make-den-fst $dir/${lang_name}.tree \
            $dir/init/${lang_name}_trans.mdl $dir/den_fsts/${lang_name}.phone_lm.fst \
            $dir/den_fsts/${lang_name}.den.fst $dir/den_fsts/${lang_name}.normalization.fst || exit 1;
  done
fi

if [ $stage -le 14 ]; then
  for lang_index in `seq 0 $[$num_langs-1]`;do
    lang_name=${lang_list[$lang_index]}
    echo "$0: Generating raw egs for $lang_name"
    train_ivector_dir=${multi_ivector_dirs[$lang_index]}
    train_data_dir=${multi_data_dirs[$lang_index]}
    lat_dir=${multi_ali_latdirs[$lang_index]}
    steps/chain2/get_raw_egs.sh \
      --alignment-subsampling-factor $frame_subsampling_factor \
      --cmd "$train_cmd" \
      --frame-subsampling-factor $frame_subsampling_factor \
      --frames-per-chunk $chunk_width \
      --lang "$lang_name" \
      --left-context $egs_left_context \
      --online-ivector-dir $train_ivector_dir \
      --right-context $egs_right_context \
      ${train_data_dir} \
      ${dir} \
      ${lat_dir} \
      ${dir}/${lang_name}_raw_egs || exit 1

    echo "$0: Processing raw egs for $lang_name"
    steps/chain2/process_egs.sh  \
      --cmd "$train_cmd" \
      ${dir}/${lang_name}_raw_egs \
      ${dir}/${lang_name}_processed_egs || exit 1
  done
fi

if [ $stage -le 15 ]; then
  echo "$0: Combining egs"
  egs_dir_list=$(for lang_index in `seq 0 $[$num_langs-1]`;do lang_name=${lang_list[$lang_index]}; echo ${dir}/${lang_name}_processed_egs; done)
  local/combine_egs.sh \
    $egs_opts \
    --cmd "$train_cmd" \
    $num_langs \
    $egs_dir_list \
    $dir/egs
fi
[[ -z $common_egs_dir ]] && common_egs_dir=${dir}/egs

if [ $stage -le 16 ]; then
  [ ! -d ${dir}/egs/misc ] && mkdir  ${dir}/egs/misc
  echo "$0: Copying den.fst to ${dir}/egs/misc"
  for lang_index in $(seq 0 $[$num_langs-1]);do
    lang_name=${lang_list[$lang_index]}
    cp $dir/den_fsts/${lang_name}.*fst ${dir}/egs/misc/
    cp $dir/init/${lang_name}_trans.mdl ${dir}/egs/misc/${lang_name}.trans_mdl
    [ -L $dir/egs/info_${lang_name}.txt ] || ln -rs $dir/egs/info.txt $dir/egs/info_${lang_name}.txt
  done
  echo "$0: Create a dummy transition model that is never used."
  first_lang_name=${lang_list[0]}
  [[ ! -f $dir/init/default_trans.mdl ]] && ln -r -s $dir/init/${first_lang_name}_trans.mdl $dir/init/default_trans.mdl
fi

if [ $stage -le 17 ]; then
  echo "$0: Preparing initial acoustic model"
  $cuda_cmd ${dir}/log/init_model.log \
  nnet3-init \
    --srand=${srand} \
    ${dir}/configs/final.config \
    ${dir}/init/multi.raw || exit 1
fi

if [ $stage -le 18 ]; then
  echo "$0: Starting model training"
  steps/chain2/train.sh \
    --cmd "$cuda_cmd" \
    --final-effective-lrate $final_effective_lrate \
    --initial-effective-lrate $initial_effective_lrate \
    --l2-regularize 5e-5 \
    --leaky-hmm-coefficient 0.25  \
    --max-param-change $max_param_change \
    --minibatch-size 128 \
    --multilingual-eg true \
    --num-jobs-final $num_jobs_final \
    --num-jobs-initial $num_jobs_initial \
    --shuffle-buffer-size 5000 \
    --srand 1 \
    --stage $train_stage \
    --xent-regularize $xent_regularize \
     $common_egs_dir $dir
fi

if [ $stage -le 19 ]; then
  echo "$0: Splitting models"
  frame_subsampling_factor=`fgrep "frame_subsampling_factor" $dir/init/info.txt | awk '{print $2}'`
  for lang_index in `seq 0 $[$num_langs-1]`;do
    lang_name=${lang_list[$lang_index]}
    [[ ! -d $dir/${lang_name} ]] && mkdir $dir/${lang_name}
    nnet3-copy --edits="rename-node old-name=output new-name=output-dummy; rename-node old-name=output-${lang_name} new-name=output" \
      $dir/final.raw - | \
      nnet3-am-init $dir/init/${lang_name}_trans.mdl - $dir/${lang_name}/final.mdl
    [[ ! -d $dir/${lang_name}/init ]] && mkdir $dir/${lang_name}/init
    params="frame_subsampling_factor model_left_context model_right_context feat_dim left_context left_context_initial right_context right_context_final ivector_dim frames_per_chunk"
    for param_name in $params; do
      grep -m 1 "^$param_name " $dir/init/info.txt
    done > $dir/${lang_name}/init/info.txt
  done
fi

if [ $stage -le 20 ]; then
  # Note: it's not important to give mkgraph.sh the lang directory with the
  # matched topology (since it gets the topology file from the model).
  # Decode mini_librispeech
  tree_dir=exp/mini_librispeech/tree
  utils/mkgraph.sh \
    --self-loop-scale 1.0 \
    data/mini_librispeech/lang_nosp_test_tgsmall \
    $tree_dir \
    $tree_dir/graph_tgsmall || exit 1;
fi

if [ $stage -le 21 ]; then
  frames_per_chunk=$(echo $chunk_width | cut -d, -f1)
  # Extract high resolution MFCCs from dev data
  utils/copy_data_dir.sh \
    data/mini_librispeech/dev_clean_2 \
    data/mini_librispeech/dev_clean_2_hires || exit 1;
  steps/make_mfcc.sh \
    --cmd "$train_cmd" \
    --mfcc-config conf/mfcc_hires.conf \
    --nj 16 \
    data/mini_librispeech/dev_clean_2_hires || exit 1;
    steps/compute_cmvn_stats.sh \
      data/mini_librispeech/dev_clean_2_hires || exit 1;
    utils/fix_data_dir.sh data/mini_librispeech/dev_clean_2_hires || exit 1;
  # Do the speaker-dependent decoding pass
  steps/online/nnet2/extract_ivectors_online.sh \
    --cmd "$train_cmd" \
    --nj 20 \
    data/mini_librispeech/dev_clean_2_hires \
    exp/multi/extractor/extractor \
    exp/mini_librispeech/ivectors_dev_clean_2_hires || exit 1;

  (
    nspk=$(wc -l <data/mini_librispeech/dev_clean_2_hires/spk2utt)
    tree_dir=exp/mini_librispeech/tree
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
      --online-ivector-dir exp/mini_librispeech/ivectors_dev_clean_2_hires \
      --post-decode-acwt 10.0 \
      $tree_dir/graph_tgsmall \
      data/mini_librispeech/dev_clean_2_hires \
      exp/chain2_multi_sp/mini_librispeech/decode_tgsmall_dev_clean_2_hires || exit 1
    steps/lmrescore_const_arpa.sh \
      --cmd "$decode_cmd" \
      data/lang_dev_tgsmall \
      data/mini_librispeech/dev_clean_2_hires \
      exp/chain2_multi_sp/decode_tgsmall_dev_clean_sp_hires || exit 1
  ) || touch $dir/.error &
  wait
  [ -f $dir/.error ] && echo "$0: there was a problem while decoding" && exit 1
fi

if [ $stage -le 22 ]; then
  nnet3-latgen-faster \
    --word-symbol-table=exp/mini_librispeech/tree/graph_tgsmall/words.txt \
    exp/chain2/tdnn_multi_sp/mini_librispeech/final.mdl \
    exp/mini_librispeech/tree/graph_tgsmall/HCLG.fst \
    'ark,s,cs:apply-cmvn  --utt2spk=ark:../s5/data/dev_clean_2_hires/utt2spk scp:../s5/data/dev_clean_2_hires/cmvn.scp scp:../s5/data/dev_clean_2_hires/feats.scp ark:- |' \
    'ark:|gzip -c > ./lat.1.gz' 
fi
exit 0;
<nnet-in>
<fst-in|fsts-rspecifier>
<features-rspecifier>
<lattice-wspecifier>
[ <words-wspecifier> [<alignments-wspecifier>] ]

nohup bash -x steps/nnet3/decode.sh --online-ivector-dir exp/mini_librispeech/ivectors_train_sp exp/mini_librispeech/tree/graph_tgsmall data/mini_librispeech/train_sp_hires exp/chain2_cleaned/tdnn_multi_sp/mini_librispeech/decode_train > XXI &
nnet3-latgen-faster \
    --online-ivectors=scp:exp/mini_librispeech/ivectors_train_sp/ivector_online.scp \
    --online-ivector-period=10 \
    --frame-subsampling-factor=3 \
    --frames-per-chunk=50 \
    --extra-left-context=0 \
    --extra-right-context=0 \
    --extra-left-context-initial=-1 \
    --extra-right-context-final=-1 \
    --minimize=false \
    --max-active=7000 \
    --min-active=200 \
    --beam=15.0 \
    --lattice-beam=8.0 \
    --acoustic-scale=0.1 \
    --allow-partial=true \
    --word-symbol-table=exp/mini_librispeech/tree/graph_tgsmall/words.txt \
    exp/chain2/tdnn_multi_sp/mini_librispeech/final.mdl \
    exp/mini_librispeech/tree/graph_tgsmall/HCLG.fst \
    "ark,s,cs:apply-cmvn --norm-means=false --norm-vars=false --utt2spk=ark:data/mini_librispeech/train_sp_hires/split4/1/utt2spk scp:data/mini_librispeech/train_sp_hires/split4/1/cmvn.scp scp:data/mini_librispeech/train_sp_hires/split4/1/feats.scp ark:- |" \
    "ark:|gzip -c >exp/chain2/tdnn_multi_sp/mini_librispeech/decode_train/lat.1.gz" 
