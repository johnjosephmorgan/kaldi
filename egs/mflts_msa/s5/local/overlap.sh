#!/usr/bin/env bash

# Get the name of a randomly chosen file
a=$(find out_dirized/*/audio_threshold -type f -name "*.wav" \! -name "sil_*"  | shuf -n 1)
# get the name of another randomly chosen file
b=$(find out_dirized/*/audio_threshold -type f -name "*.wav" \! -name "sil_*"  | shuf -n 1)
# Make the name for a silence buffered version of b
a_base=$(basename $a)
a_dir=$(dirname $a)
a_sil=$a_dir/sil_${a_base}
# Concatenate the silent buffer with b
sox $a_sil $b c.wav
# Make the overlapped recording
sox $a c.wav -c 2 stereo.wav -M
# Merge the 2 channels by averaging the samples
sox stereo.wav mono.wav channels 1
