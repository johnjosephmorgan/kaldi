#!/bin/bash

# Create a corpus of overlapping speech

# source the path.sh file to get the value of the KALDI_ROOT variable.
. ./path.sh
stage=0
num_pairs=1000
num_overlaps=1000
. utils/parse_options.sh
# Get the Kaldi SAD and Diarization models
local/download_kaldi_models.sh

# Make the directory where we store all the work
mkdir -p out_diarized

# Each iteration of the following loop processes a pair of recordings
for ((i=0;i<=num_pairs;i++)); do
  # Get the source waveform files
  echo "Getting pairs of recordings number $i."
  local/get_and_convert_data.sh

  # segment and diarize
  local/run_segmentation.sh

  # use sox to get information about wav files
  echo "Getting file info."
  local/get_info.sh

  # Each iteration of the following loop generates overlaps
  for ((j=0;j<=num_overlaps;j++)); do
    echo "$j run of overlap writing."
    local/overlap.sh
  done
done
exit
