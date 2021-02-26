#!/bin/bash

# Create a corpus of overlapping speech

# source the path.sh file to get the value of the KALDI_ROOT variable.
. ./path.sh
num_pairs=10000
num_overlaps=10000
stage=0
. utils/parse_options.sh


if [ $stage -le 0 ]; then
  # Get the Kaldi SAD and Diarization models
  local/download_kaldi_models.sh
fi

# Make the directory where we store all the work
mkdir -p out_diarized

if [ $stage -le 1 ]; then
  # Get and prepare the  source waveform recording files
  local/get_and_convert_data.sh
fi

if [ $stage -le 2 ]; then
  # segment and diarize the recordings
  local/run_segmentation.sh
fi
exit
if [ $stage -le 3 ]; then
  for rec in out_diarized/flacs/*; do
    # Write segment .wav files from thresholded clustering."
    base=$(basename $rec .flac)
    ./local/labels2wav_3.pl $rec out_diarized/work/recordings/$base
  done
fi

if [ $stage -le 4 ]; then
  # use sox to get information about wav files
  local/get_info.sh
fi

if [ $stage -le 5 ]; then
  mkdir -p out_diarized/overlaps
  n=$(find out_diarized/work/speakers -type f -name "*.wav" | wc -l)
  for ((i=0;i<=n;i++)); do
    s1=$(find out_diarized/work/speakers -type f -name "*.wav" | shuf -n 1)
    s2=$(find out_diarized/work/speakers -type f -name "*.wav" | shuf -n 1)
    local/overlap.sh $s1 $s2
    rm $s1 $s2
  done
fi

if [ $stage -le 6 ]; then
    mkdir -p out_diarized/concats
  n=$(find out_diarized/overlaps -type f -name "max.wav" | wc -l)
  for ((i=0;i<=n;i++)); do
    local/concatenate_wavs.sh $i
  done
fi
