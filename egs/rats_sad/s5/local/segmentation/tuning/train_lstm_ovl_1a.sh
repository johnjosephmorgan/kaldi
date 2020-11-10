#!/usr/bin/env bash

# Copyright 2017   Nagendra Kumar Goel
#           2018   Vimal Manohar
# Apache 2.0

# This is a script to train a TDNN for speech activity detection (SAD) 
# using LSTM for long-context information.

stage=0
train_stage=-10
get_egs_stage=-10
egs_opts=

chunk_width=20

extra_left_context=60
extra_right_context=10
relu_dim=256
cell_dim=256
projection_dim=64

# training options
num_epochs=1
initial_effective_lrate=0.0003
final_effective_lrate=0.00003
num_jobs_initial=1
num_jobs_final=1
remove_egs=true
max_param_change=0.2  # Small max-param change for small network
dropout_schedule='0,0@0.20,0.1@0.50,0'

egs_dir=
nj=10


affix=1a
dir=exp/overlap_${affix}
data_dir=
targets_dir=

. ./cmd.sh
if [ -f ./path.sh ]; then . ./path.sh; fi
. ./utils/parse_options.sh

set -o pipefail
set -u

dir=$dir${affix:+_$affix}

if ! cuda-compiled; then
  cat <<EOF && exit 1
This script is intended to be used with GPUs but you have not compiled Kaldi with CUDA
If you want to use GPUs (and have them), go to src/, and configure and make on a machine
where "nvcc" is installed.
EOF
fi

mkdir -p $dir

samples_per_iter=`perl -e "print int(400000 / $chunk_width)"`
cmvn_opts="--norm-means=false --norm-vars=false"
echo $cmvn_opts > $dir/cmvn_opts

if [ $stage -le 5 ]; then
  echo "$0: creating neural net configs using the xconfig parser";
  
  mkdir -p $dir/configs
  cat <<EOF > $dir/configs/network.xconfig
  input dim=`feat-to-dim scp:$data_dir/feats.scp -` name=input
  fixed-affine-layer name=lda input=Append(-2,-1,0,1,2) affine-transform-file=$dir/configs/lda.mat 

  relu-renorm-layer name=tdnn1 input=lda dim=$relu_dim add-log-stddev=true
  relu-renorm-layer name=tdnn2 input=Append(-1,0,1,2) dim=$relu_dim add-log-stddev=true
  relu-renorm-layer name=tdnn3 input=Append(-3,0,3,6) dim=$relu_dim add-log-stddev=true
  fast-lstmp-layer name=lstm1 cell-dim=$cell_dim recurrent-projection-dim=$projection_dim non-recurrent-projection-dim=$projection_dim decay-time=20 delay=-3 dropout-proportion=0.0
  relu-renorm-layer name=tdnn4 input=Append(-6,0,6,12) add-log-stddev=true dim=$relu_dim
  fast-lstmp-layer name=lstm2 cell-dim=$cell_dim recurrent-projection-dim=$projection_dim non-recurrent-projection-dim=$projection_dim decay-time=20 delay=-3 dropout-proportion=0.0
  relu-renorm-layer name=tdnn5 input=Append(-12,0,12,24) dim=$relu_dim

  output-layer name=output include-log-softmax=true dim=3 learning-rate-factor=0.1 input=tdnn5
EOF
  steps/nnet3/xconfig_to_configs.py --xconfig-file $dir/configs/network.xconfig \
    --config-dir $dir/configs/

  cat <<EOF >> $dir/configs/vars
num_targets=3
EOF
fi

if [ $stage -le 6 ]; then
  num_utts=`cat $data_dir/utt2spk | wc -l`
  # Set num_utts_subset for diagnostics to a reasonable value
  # of max(min(0.005 * num_utts, 300), 12)
  num_utts_subset=`perl -e '$n=int($ARGV[0] * 0.005); print ($n > 300 ? 300 : ($n < 12 ? 12 : $n))' $num_utts`

  steps/nnet3/train_raw_rnn.py --stage=$train_stage \
    --feat.cmvn-opts="--norm-means=false --norm-vars=false" \
    --egs.chunk-width=$chunk_width \
    --egs.dir="$egs_dir" --egs.stage=$get_egs_stage \
    --egs.chunk-left-context=$extra_left_context \
    --egs.chunk-right-context=$extra_right_context \
    --egs.chunk-left-context-initial=0 \
    --egs.chunk-right-context-final=0 \
    --trainer.num-epochs=$num_epochs \
    --trainer.samples-per-iter=20000 \
    --trainer.optimization.num-jobs-initial=$num_jobs_initial \
    --trainer.optimization.num-jobs-final=$num_jobs_final \
    --trainer.optimization.initial-effective-lrate=$initial_effective_lrate \
    --trainer.optimization.final-effective-lrate=$final_effective_lrate \
    --trainer.optimization.shrink-value=0.99 \
    --trainer.dropout-schedule="$dropout_schedule" \
    --trainer.rnn.num-chunk-per-minibatch=128,64 \
    --trainer.optimization.momentum=0.5 \
    --trainer.deriv-truncate-margin=10 \
    --trainer.max-param-change=$max_param_change \
    --trainer.compute-per-dim-accuracy=true \
    --cmd="$decode_cmd" --nj $nj \
    --cleanup=true \
    --cleanup.remove-egs=$remove_egs \
    --cleanup.preserve-model-interval=10 \
    --use-gpu=true \
    --use-dense-targets=true \
    --feat-dir=$data_dir \
    --targets-scp="$targets_dir/targets.scp" \
    --egs.opts="--frame-subsampling-factor 1 --num-utts-subset $num_utts_subset" \
    --dir=$dir || exit 1
fi

if [ $stage -le 7 ]; then
  # Use a subset to compute prior over the output targets
  $train_cmd $dir/log/get_priors.log \
    matrix-sum-rows "scp:utils/subset_scp.pl --quiet 1000 $targets_dir/targets.scp |" \
    ark:- \| vector-sum --binary=false ark:- $dir/post_output.vec || exit 1

  echo 1 > $dir/frame_subsampling_factor
fi
