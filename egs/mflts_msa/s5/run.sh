#!/bin/bash

# Create a corpus of overlapping speech

# source the path.sh file to get the value of the KALDI_ROOT variable.
. ./path.sh

# Start setting variables
datadir=/mnt/corpora/mflts
num_pairs=10000
num_overlaps=10000
stage=0
# Stop setting variables

. utils/parse_options.sh

if [ $stage -le 0 ]; then
  # Get the Kaldi SAD and Diarization models
  local/download_kaldi_models.sh
fi

# Make the directory where we store all the work
mkdir -p work

if [ $stage -le 1 ]; then
  # Get and prepare the  source waveform recording files
  local/get_and_convert_data.sh $datadir
fi

if [ $stage -le 2 ]; then
  # segment and diarize the recordings
  local/run_segmentation.sh
fi

if [ $stage -le 3 ]; then
  mkdir -p work/segmented
  for rec in work/flacs/*; do
    # Write segment .wav files from thresholded clustering."
    base=$(basename $rec .flac)
    ./local/labels2wav.pl $rec work/segments/$base
  done
fi

if [ $stage -le 4 ]; then
  # use sox to get information about wav files
  local/get_info.sh
fi

if [ $stage -le 5 ]; then
  # Write the duration information to file
  # We ran the previous stage separately because it uses sox 
  local/get_samples.sh
fi

if [ $stage -le 6 ]; then
  mkdir -p out_diarized/overlaps
  n=$(find out_diarized/work/speakers -type f -name "*_samples.txt" | wc -l)
  #echo "There are $n sample files."
  # Loop a lot of times
  for ((i=0;i<=n;i++)); do
    # randomly choose files to process
    s1=$(find out_diarized/work/speakers -type f -name "*_samples.txt" | shuf -n 1)
    s2=$(find out_diarized/work/speakers -type f -name "*_samples.txt" | shuf -n 1)
    local/overlap.sh $s1 $s2
    # delete the 2 files we just processed
    # this should implement sampling without replacement
    rm $s1 $s2
  done
fi

if [ $stage -le 7 ]; then
    mkdir -p out_diarized/concats
  n=$(find out_diarized/overlaps -type f -name "max.wav" | wc -l)
  for ((i=0;i<=n;i++)); do
    local/concatenate_wavs.sh $i
  done
fi

# write the rttm files
if [ $stage -le 8 ]; then
   for i in out_diarized/concats/*; do
       local/pairs2rttm.pl $i
   done
fi
