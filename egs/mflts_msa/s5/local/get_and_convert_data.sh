#!/usr/bin/env bash
# retrieve 1 randomly selected wav file.
# Convert fiels from 2 channel wav files sampled at 44100 to single channel flac files sampled at 16k
datadir=~/mflts
[ -d $datadir ] || exit 1;

# Write a file with a list of the input source waveform files
$(find $datadir -type f -name "*sif.wav" | shuf -n 1 > out_diarized/wavlist.txt)
{
  while read line; do
    bn=$(basename "$line" .wav)
    mkdir -p out_diarized/flacs
    sox "$line" -c 1 -r 16000 out_diarized/flacs/$bn.flac
  done
} < out_diarized/wavlist.txt;
