#!/usr/bin/env bash

# retrieve  wav file.
# Convert fiels from 2 channel wav files sampled at 44100 to single channel flac files sampled at 16k
# Write the flac file under work/flacs

datadir=$1
workdir=work

[ -d $datadir ] || exit 1;

# Write a file with a list of the input  source waveform files
# We only use the sif.wav files.
$(find $datadir -type f -name "*sif.wav"  > $workdir/wavlist.txt)

# Run sox on each file in the list
{
  while read line; do
    bn=$(basename "$line" .wav)
    mkdir -p $workdir/flacs
    sox "$line" -c 1 -r 16000 $workdir/flacs/$bn.flac
  done
} < $workdir/wavlist.txt;
