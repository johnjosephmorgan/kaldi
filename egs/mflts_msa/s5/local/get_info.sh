#!/usr/bin/env bash

# This script Gets duration information for the segmented audio recordings.
# the audio recordings are stored under $workdir/speakers
# The information for each audio file is stored in a file called samples.txt
if [ $# -ne 1 ]; then
    echo "USAGE $0 <WORK_DIR>"
    exit 1;
fi

workdir=$1

# loop over each speaker directory
for s in $workdir/speakers/*; do
  # loop over each segment for the current speaker
  for f in $s/*.wav; do
    [ ! -f $f ] && exit 1;
      # Get the basename for the current audio file
      base=$(basename $f .wav)
      # get the path to the current speaker directory
      spk_path=$(dirname $f)
      # get the current speaker id
      spk=$(basename $spk_path)
      # make a name for the directory where we will store the work for the current audio files
      dir=$workdir/samples/$spk
      # make the output directory
      mkdir -p $dir
      # use sox to get  information on  current file and store in info.txt
      sox --i $f | egrep "Input|Duration" > $dir/${base}_info.txt
      # extract duration from info.txt
      cat $dir/${base}_info.txt | grep Duration | cut -d "=" -f 2 | cut -d "~" -f 1 | cut -d " " -f 2 > $dir/${base}_duration.txt
      # extract  filename from info.txt
      cat $dir/${base}_info.txt | grep "Input" | cut -d ":" -f 2 | tr -d "'" > $dir/${base}_filename.txt
      # put filename and duration into samples.txt
      paste $dir/${base}_filename.txt $dir/${base}_duration.txt > $dir/${base}_samples.txt
  done
done
