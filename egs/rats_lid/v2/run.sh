#!/usr/bin/env bash

. ./cmd.sh
. ./path.sh
set -e

#datadir=/mnt/corpora/LDC2015S02/RATS_SAD/data
datadir=/export/corpora5/LDC/LDC2015S02/data
stage=0
. utils/parse_options.sh

# Retrieve the supervision files and store the data
if [ $stage -le 0 ]; then
  for f in dev-1 dev-2 train; do
    echo "Retrieving $f supervision files."
    mkdir -p data/$f
    find $datadir/$f/sad -type f -name "*.tab" | xargs cat > \
      data/$f/annotation.txt
    echo "Writing utt2lang for $f."
    cut -f 2,9 data/$f/annotation.txt > data/$f/utt2lang.txt
  done
fi

# Retrieve the paths to the audio files.
if [ $stage -le 1 ]; then
  for d in train dev-1 dev-2; do
    echo "Retrieving paths to audio files for $d."
    find $datadir/$d/audio -type f -name "*.flac" > data/$d/flac.txt
  done
fi

# Write supervision files. 
if [ $stage -le 2 ]; then
  echo "Writing supervision files."
  local/rats_sad_make_supervision.pl
fi

if [ $stage -le 3 ]; then
  for x in dev-1 dev-2 train; do
    echo "Write spk2utt for $x."
    utils/utt2spk_to_spk2utt.pl data/$x/utt2spk > data/$x/spk2utt
  done
fi

# Extract MFCC features
if [ $stage -le 4 ]; then
  for f in dev-1 dev-2 train; do
    echo "Extracting MFCC features for $f."
    utils/fix_data_dir.sh data/$f
    steps/make_mfcc.sh --write-utt2num-frames true --mfcc-config conf/mfcc_hires.conf \
      --nj 40 --cmd "$train_cmd" data/$f
    utils/fix_data_dir.sh data/$f
  done
fi

if [ $stage -le 5 ]; then
  local/nnet3/xvector/prepare_feats_for_egs.sh --nj 40 --cmd "$train_cmd" \
    data/train data/train_no_sil exp/train_no_sil
  utils/fix_data_dir.sh data/train_no_sil
fi
