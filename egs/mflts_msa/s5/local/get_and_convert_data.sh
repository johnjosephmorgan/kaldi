#!/usr/bin/env bash
# retrieve 2 randomly selected wav files .
# Convert fiels from 2 channel wav files sampled at 44100 to single channel flac files sampled at 16k
datadir=~/mflts
wavlist=$(find $datadir -type f -name "*sif.wav" | shuf -n 2)
{
  while read line; do
    bn=$(basename "$line" .wav)
    mkdir -p flacs
    sox "$line" -c 1 -r 16000 flacs/$bn.flac
  done
} < wavlist.txt;
