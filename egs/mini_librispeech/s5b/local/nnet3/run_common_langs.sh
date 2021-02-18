#!/usr/bin/env bash

# Copyright 2016 Pegah Ghahremani

# This script used to generate MFCC features for input language lang.

. ./cmd.sh
set -e

boost_sil=1.0 # Factor by which to boost silence likelihoods in alignment
feat_suffix=_hires  # feature suffix for training data
generate_alignments=true # If true, it regenerates alignments.
speed_perturb=true
stage=1
train_stage=-10

. ./utils/parse_options.sh

lang=$1

# perturbed data preparation
train_set=train

if [ $# -ne 1 ]; then
  echo "Usage:$0 [options] <language-id>"
  echo "e.g. $0 tamsa"
  exit 1;
fi

if [ $stage -le 1 ]; then
  #Although the nnet model will be trained by high resolution data, we still have to perturbe the normal data to get the alignment
  # _sp stands for speed-perturbed
  for datadir in train; do
    ./utils/data/perturb_data_dir_speed_3way.sh data/$lang/${datadir} data/$lang/${datadir}_sp
    # Extract  features for perturbed data.
    steps/make_mfcc.sh --cmd "$train_cmd" --nj 16 data/$lang/${datadir}_sp 
    steps/compute_cmvn_stats.sh data/$lang/${datadir}_sp
    utils/fix_data_dir.sh data/$lang/${datadir}_sp
  done
fi

train_set=train_sp
if [ $stage -le 2 ]; then
  #obtain the alignment of the perturbed data
  steps/align_fmllr.sh \
    --nj 16 --cmd "$train_cmd" \
    --boost-silence $boost_sil \
    data/$lang/$train_set data/$lang/lang exp/$lang/tri3b exp/$lang/tri3b_ali_sp || exit 1;
  touch exp/$lang/tri3b_ali_sp/.done
fi

hires_config="--mfcc-config conf/mfcc_hires.conf"
mfccdir=mfcc_hires/$lang
mfcc_affix=""

if [ $stage -le 3 ] && [ ! -f data/$lang/${train_set}${feat_suffix}/.done ]; then
  if [[ $(hostname -f) == *.clsp.jhu.edu ]] && [ ! -d $mfccdir/storage ]; then
    date=$(date +'%m_%d_%H_%M')
    utils/create_split_dir.pl /export/b0{1,2,3,4}/$USER/kaldi-data/egs/$lang-$date/s5c/$mfccdir/storage $mfccdir/storage
  fi

  for dataset in $train_set ; do
    data_dir=data/$lang/${dataset}${feat_suffix}
    log_dir=exp/$lang/make${feat_suffix}/$dataset

    utils/copy_data_dir.sh data/$lang/$dataset ${data_dir} || exit 1;

    # scale the waveforms, this is useful as we don't use CMVN
    utils/data/perturb_data_dir_volume.sh $data_dir || exit 1;

    steps/make_mfcc${mfcc_affix}.sh --nj 16 $hires_config \
      --cmd "$train_cmd" ${data_dir} $log_dir $mfccdir;

    steps/compute_cmvn_stats.sh ${data_dir} $log_dir $mfccdir;

    # Remove the small number of utterances that couldn't be extracted for some
    # reason (e.g. too short; no such file).
    utils/fix_data_dir.sh ${data_dir};
  done
  touch ${data_dir}/.done
fi
exit 0;