#!/usr/bin/env bash

. ./cmd.sh
. ./path.sh
set -e

#datadir=/mnt/corpora/LDC2015S02/RATS_SAD/data
datadir=/export/corpora5/LDC/LDC2015S02/data
nnet_dir=exp/xvector_nnet_1a
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
    sid/compute_vad_decision.sh --nj 40 --cmd "$train_cmd" data/$f

    utils/fix_data_dir.sh data/$f
  done
fi

if [ $stage -le 5 ]; then
  local/nnet3/xvector/prepare_feats_for_egs.sh --nj 5 --cmd "$train_cmd" \
    data/train data/train_no_sil exp/train_no_sil
  utils/fix_data_dir.sh data/train_no_sil
fi

if [ $stage -le 6 ]; then
  # Now, we need to remove features that are too short after removing silence
  # frames.  We want atleast 5s (500 frames) per utterance.
  min_len=400
  mv data/train_no_sil/utt2num_frames data/train_no_sil/utt2num_frames.bak
  awk -v min_len=${min_len} '$2 > min_len {print $1, $2}' data/train_no_sil/utt2num_frames.bak > data/train_no_sil/utt2num_frames
  utils/filter_scp.pl data/train_no_sil/utt2num_frames data/train_no_sil/utt2spk > data/train_no_sil/utt2spk.new
  mv data/train_no_sil/utt2spk.new data/train_no_sil/utt2spk
  utils/fix_data_dir.sh data/train_no_sil

  # We also want several utterances per speaker. Now we'll throw out speakers
  # with fewer than 8 utterances.
  min_num_utts=8
  awk '{print $1, NF-1}' data/train_no_sil/spk2utt > data/train_no_sil/spk2num
  awk -v min_num_utts=${min_num_utts} '$2 >= min_num_utts {print $1, $2}' data/train_no_sil/spk2num | utils/filter_scp.pl - data/train_no_sil/spk2utt > data/train_no_sil/spk2utt.new
  mv data/train_no_sil/spk2utt.new data/train_no_sil/spk2utt
  utils/spk2utt_to_utt2spk.pl data/train_no_sil/spk2utt > data/train_no_sil/utt2spk

  utils/filter_scp.pl data/train_no_sil/utt2spk data/train_no_sil/utt2num_frames > data/train_no_sil/utt2num_frames.new
  mv data/train_no_sil/utt2num_frames.new data/train_no_sil/utt2num_frames

  # Now we're ready to create training examples.
  utils/fix_data_dir.sh data/train_no_sil
fi

if [ $stage -le 7 ]; then
local/nnet3/xvector/run_xvector.sh --stage $stage --train-stage -1 \
  --data data/train_no_sil --nnet-dir $nnet_dir \
  --egs-dir $nnet_dir/egs
fi

if [ $stage -le 10 ]; then
  # Extract x-vectors for centering, LDA, and PLDA training.
  sid/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd --mem 4G" --nj 5 \
    $nnet_dir data/train \
    $nnet_dir/xvectors_train

  # Extract x-vectors used in the evaluation.
  sid/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd --mem 4G" --nj 3 \
    $nnet_dir data/dev-1 \
    $nnet_dir/xvectors_dev-1
fi

if [ $stage -le 11 ]; then
  # Compute the mean vector for centering the evaluation xvectors.
  $train_cmd $nnet_dir/xvectors_train/log/compute_mean.log \
    ivector-mean scp:$nnet_dir/xvectors_train/xvector.scp \
    $nnet_dir/xvectors_train/mean.vec || exit 1;

  # This script uses LDA to decrease the dimensionality prior to PLDA.
  lda_dim=200
  $train_cmd $nnet_dir/xvectors_train/log/lda.log \
    ivector-compute-lda --total-covariance-factor=0.0 --dim=$lda_dim \
    "ark:ivector-subtract-global-mean scp:$nnet_dir/xvectors_train/xvector.scp ark:- |" \
    ark:data/train/utt2spk $nnet_dir/xvectors_train/transform.mat || exit 1;

  # Train the PLDA model.
  $train_cmd $nnet_dir/xvectors_train/log/plda.log \
    ivector-compute-plda ark:data/train/spk2utt \
    "ark:ivector-subtract-global-mean scp:$nnet_dir/xvectors_train/xvector.scp ark:- | transform-vec $nnet_dir/xvectors_train/transform.mat ark:- ark:- | ivector-normalize-length ark:-  ark:- |" \
    $nnet_dir/xvectors_train/plda || exit 1;
fi
