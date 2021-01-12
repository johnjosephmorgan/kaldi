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
    find $datadir/$f/sad -type f -name "*.tab" | xargs cat > data/$f/annotation.txt
    cut -f 2,9 data/$f/annotation.txt > data/$f/utt2lang
    cut -f 1 data/$f/utt2lang > data/$f/utt.txt
  done
fi

if [ $stage -le 1 ]; then
  for d in train dev-1 dev-2; do
    find $datadir/$d/audio -type f -name "*.flac" > data/$d/flac.txt
  done
fi

if [ $stage -le 2 ]; then
  local/rats_sad_make_wav.scp.pl
fi

if [ $stage -le 3 ]; then
    local/rats_sad_make_utt2spk.pl
fi

if [ $stage -le 4 ]; then
  for x in dev-1 dev-2 train; do
    utils/utt2spk_to_spk2utt.pl data/$x/utt2spk > data/$x/spk2utt
  done
fi

if [ $stage -le 5 ]; then
  for f in dev-1 dev-2 train; do
    steps/make_mfcc.sh --write-utt2num-frames true --mfcc-config conf/mfcc_hires.conf \
      --nj 40 --cmd "$train_cmd" data/$f
    utils/fix_data_dir.sh data/$f
  done
fi
