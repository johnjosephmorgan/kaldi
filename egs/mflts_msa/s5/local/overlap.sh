#!/usr/bin/env bash

dir=out_diarized/work
buffs=$dir/buffs
stereos=$dir/stereos
olaps=$dir/olaps
mkdir -p $buffs $stereos $olaps

# Get the name of a randomly chosen file
a=$(find $dir/*/audio_threshold -type f -name "*.wav" \! -name "sil_*"  | shuf -n 1)
echo "a $a"

# get the name of another randomly chosen file
b=$(find $dir/*/audio_threshold -type f -name "*.wav" \! -name "sil_*"  | shuf -n 1)
echo "b $b"

# Make the name for a silence buffered version of b
a_base=$(basename $a)
echo "a base $a_base"
b_base=$(basename $b)
echo "b base $b_base"
a_dir=$(dirname $a)
echo "a dir $a_dir"
b_dir=$(dirname $b)
echo "b dir $b_dir"
a_sil=$a_dir/sil_${a_base}
echo "a sil $a_sil"
a_sil_base=$(basename $a_sil .wav)
echo "a sil base $a_sil_base"

# Make a name for the silence buffered version of b
b_buff=$buffs/${a_sil_base}_${b_base}
echo "b buff $b_buff"

# Concatenate the silent buffer with b
sox $a_sil $b ${b_buff}

# Make the name for the overlap recording file
b_buff_base=$(basename $b_buff .wav)
echo "b buff base $b_buff_base"
c=$stereos/$b_buff_base
echo "c $c"

# Make the overlapped recording
sox $a $b_buff -c 2 $c.wav -M

# Make the name for the merged recording file
c_base=$(basename $c .wav)
echo "c base $c_base"
d=$olaps/$c_base

# Merge the 2 channels by averaging the samples
sox $c.wav $d.wav channels 1
