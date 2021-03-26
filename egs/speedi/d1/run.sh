#!/bin/bash

# Diarization pipeline

# source the path.sh file to get the value of the KALDI_ROOT variable.
. ./path.sh

# Start setting variables
#datadir=/mnt/corpora/LDC2019S12/data/flac
datadir=~/flac
num_concatenated_pairs=50
stage=0
workdir=work
# Stop setting variables

. utils/parse_options.sh

if [ $stage -le 0 ]; then
  # Get the Kaldi SAD and Diarization models
  local/download_kaldi_models.sh
fi

# Make the directory where we store all the work
[ -d $workdir ] || mkdir -p $workdir;

if [ $stage -le 1 ]; then
  # segment and diarize the recordings
  for src in $datadir/*; do
    local/run_segmentation.sh $src $workdir
  done
fi

if [ $stage -le 2 ]; then
  for rec in $datadir/*; do
    # Write segment .wav files from thresholded clustering.
    # the files are written to directories under $workdir/speakers.
    # There is a directory for each speaker.
    base=$(basename $rec .flac)
    local/labels2wav.pl $workdir $rec $workdir/recordings/$base
  done
fi

if [ $stage -le 3 ]; then
    for s in $workdir/speakers/*; do
    for f in $s/*; do
      # Make the name for the maxed volume file
      base=$(basename $f .wav)
      d=$(dirname $f)
      max=$d/${base}_max.wav
      # Make a name for thestats file
      vc=$d/${base}_vc.txt
      # Get stats 
      sox $f -n stat -v 2> $vc
      # Write the volume maxed file
      sox -v $(cat $vc) $f $max
    done
  done
fi
