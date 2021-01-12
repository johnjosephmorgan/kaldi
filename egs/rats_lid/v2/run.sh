#!/usr/bin/env bash

. ./cmd.sh
. ./path.sh
set -e

datadir=/mnt/corpora/LDC2015S02/RATS_SAD/data
stage=0
. utils/parse_options.sh

if [ $stage -le 0 ]; then
  for f in train dev-1 dev-2; do
    mkdir -p data/$f
    find $datadir/$f/sad -type f -name "*.tab" | xargs cat > data/$f.txt
    cut -f 2,9 data/$f.txt > data/$f/utt2lang
    cut -f 2 data/$f.txt > data/$f/utt.txt
  done
fi

if [ $stage -le 1 ]; then
  local/rats_sad_utt2lang_to_flac_list.sh $datadirr
fi

if [ $stage -le 2 ]; then
    for f in dev-1 dev-2 train; do
	local/rats_sad_flac2wav.scp.pl data/$f/flac.txt
    done
fi

if [ $stage -le 3 ]; then
  for f in dev-1 dev-2 train; do
    make_mfcc.sh --write-utt2num-frames true --mfcc-config conf/mfcc_hires.conf \
      --nj 40 --cmd "$train_cmd" data/$f
    utils/fix_data_dir.sh data/$f
  done
fi
