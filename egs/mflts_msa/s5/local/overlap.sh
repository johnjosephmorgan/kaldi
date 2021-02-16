#!/usr/bin/env bash

dir=out_diarized/work
mkdir -p  $dir

# Get the name of a randomly chosen file
a_sil=$(find $dir/*/audio_threshold/*/sils -type f -name "*.wav" | shuf -n 1)
echo "a sil $a_sil"

# get the name of another randomly chosen file
b_samples=$(find $dir/*/audio_threshold/* -type f -name "*_samples.txt" | shuf -n 1)
echo "b  samples $b_samples"

a_sil_dir=$(dirname $a_sil)
echo "a sil dir $a_sil_dir"
b_dir=$(dirname $b_samples)
echo "b dir $b_dir"

a_dir=$(dirname $a_sil_dir) 
echo "a dir $a_dir"

# Make the name for a silence buffered version of b
a_sil_base=$(basename $a_sil .wav)
echo "a sil base $a_sil_base"

# Get the original wav file
a=$a_dir/$a_sil_base.wav
echo "a $a"

# Get the b base
b_base=$(basename $b_samples _samples.txt)
echo "b base $b_base"

# What is b?
b=$b_dir/$b_base.wav
echo "b $b"
# Make a name for the silence buffered version of b
b_buff=$a_dir/buffs/${a_sil_base}_${b_base}.wav
echo "b buff $b_buff"

b_buff_dir=$(dirname $b_buff)
echo "b buff dir $b_buff_dir"

mkdir -p $b_buff_dir

# Concatenate the silent buffer with b
echo "Concatenating $a_sil and $b and storing in $b_buff"
sox $a_sil $b $b_buff

# Make the name for the overlap recording file
b_buff_base=$(basename $b_buff .wav)
echo "b buff base $b_buff_base"

# Make the name for the stereos directory
stereos=$a_dir/stereos
echo "stereos $stereos"
mkdir -p $stereos

# Make the name for the stereo file
c=$stereos/$b_buff_base.wav
echo "c $c"

# Make the stereo recording
echo "Write a stereo file with $a and $b_buff"
sox $a $b_buff -c 2 $c -M

# Make the name for the overlaps directory
olaps_dir=$a_dir/olaps
echo "overlaps directory name $olaps_dir"
mkdir -p $olaps_dir

# Make the name for the merged recording file
c_base=$(basename $c .wav)
echo "c base $c_base"
d=$olaps_dir/${c_base}.wav
echo "d $d"

# Merge the 2 channels by averaging the samples
sox $c $d channels 1

d_base=$(basename $d .wav)
echo "d base $d_base"

d_dir=$(dirname $d)
echo " d dir $d_dir"

e_dir=$a_dir/maxed_overlaps
mkdir -p $e_dir
e=$e_dir/$d_base.wav
sox $d -n stat -v 2> vc
sox -v $(cat vc) $d $e
