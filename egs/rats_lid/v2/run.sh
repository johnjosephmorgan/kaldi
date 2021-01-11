#!/usr/bin/env bash

. ./cmd.sh
. ./path.sh
set -e

datadir=/mnt/corpora/LDC2015S02/RATS_SAD/data
stage=0

if [ $stage -le 0 ]; then
  local/rats_sad_get_filenames.sh $datadir
fi

if [ $stage -le 1 ]; then
  for f in dev-1 dev-2 train; do
    local/rats_sad_data_prep.pl data/local/annotations/$f.txt
  done
fi

if [ $stage -le 2 ]; then
  local/rats_sad_utt2lang_to_flac_list.sh $datadirr
fi

if [ $stage -le 3 ]; then
    for f in dev-1 dev-2 train; do
	local/rats_sad_flac2wav.scp.pl data/$f/flac.txt
    done
fi

if [ $stage -le 4 ]; then
  for f in dev-1 dev-2 train; do
    make_mfcc.sh --write-utt2num-frames true --mfcc-config conf/mfcc_hires.conf \
      --nj 40 --cmd "$train_cmd" data/$f
    utils/fix_data_dir.sh data/$f
  done
fi
