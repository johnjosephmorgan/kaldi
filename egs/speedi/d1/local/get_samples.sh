#!/usr/bin/env bash

# This script makes the files containing the number of samples
if [ $# -ne 1 ]; then
  echo "USAGE: $0 <WORK_DIR>"
  exit 1;
fi
workdir=$1
# loop over each speaker directory
for s in $workdir/speakers/*; do
  # loop over each segment for the current speaker
    for f in $s/*.wav; do
      # Get the basename for the current audio file
      base=$(basename $f .wav)
      # get the path to the current speaker directory
      spk_path=$(dirname $f)
      # get the current speaker id
      spk=$(basename $spk_path)
      # make a name for the directory where we will store the work for the current audio files
      dir=$workdir/samples/$spk
      # put filename and duration into samples.txt
      paste $dir/${base}_filename.txt $dir/${base}_duration.txt > $dir/${base}_samples.txt
      rm $dir/${base}_filename.txt $dir/${base}_duration.txt $dir/${base}_info.txt
  done
done
