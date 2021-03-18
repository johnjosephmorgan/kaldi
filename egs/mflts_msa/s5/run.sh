#!/bin/bash

# Create a corpus of overlapping speech

# source the path.sh file to get the value of the KALDI_ROOT variable.
. ./path.sh

# Start setting variables
datadir=~/mflts
num_concatenated_pairs=1000
num_overlaps=10000
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
  # Get and prepare the  source waveform recording files
  local/get_and_convert_data.sh $datadir $workdir
fi

if [ $stage -le 2 ]; then
  # segment and diarize the recordings
  local/run_segmentation.sh $workdir
fi

if [ $stage -le 3 ]; then
  for rec in $workdir/flacs/*; do
    # Write segment .wav files from thresholded clustering.
    # the files are written to directories under $workdir/speakers.
    # There is a directory for each speaker.
    # Each recording has 3 speakers
    # The Soldier, The motorist and the interpretor.
    base=$(basename $rec .flac)
    ./local/labels2wav.pl $workdir $rec $workdir/recordings/$base
  done
fi

if [ $stage -le 4 ]; then
    # use sox to get information about wav files
    # The information is written to files with extension _samples.txt
  local/get_info.sh $workdir
fi

if [ $stage -le 5 ]; then
  # Write the duration information to file
  # We ran the previous stage separately because it uses sox
  # We store the files under $workdir/samples
  local/get_samples.sh $workdir
fi

if [ $stage -le 6 ]; then
  mkdir -p $workdir/overlaps
  n=$(find $workdir/samples -type f -name "*_samples.txt" | wc -l)
  echo "There are $n sample files."
  ((m=n/2))
  # Loop a lot of times
  for ((i=0;i<=m;i++)); do
    # randomly choose files to process
    s1=$(find $workdir/samples -type f -name "*_samples.txt" | shuf -n 1)
    s2=$(find $workdir/samples -type f -name "*_samples.txt" | shuf -n 1)
    local/overlap.sh $workdir $s1 $s2
    # delete the 2 files we just processed
    # this should implement sampling without replacement
    [ -f $s1 ] && rm $s1;
    [ -f $s2 ] && rm $s2;
  done
fi

if [ $stage -le 7 ]; then
  mkdir -p $workdir/concats
  n=$(find $workdir/overlaps -type f -name "max.wav" | wc -l)
  echo "There are $n overlap pairs."
  for ((i=0;i<=n;i++)); do
    local/concatenate_wavs.sh $workdir $i $num_concatenated_pairs
  done
  find $workdir -empty -delete
fi

# write the rttm files
if [ $stage -le 8 ]; then
  for i in $workdir/concats/*; do
    local/pairs2rttm.pl $i
   done
fi
