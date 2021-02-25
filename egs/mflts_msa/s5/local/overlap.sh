#!/usr/bin/env bash

if [ $# -ne 2 ]; then
  echo "UsAGE: $0 <FLAC_FILE_1> <FLAC_FILE_2>";
    exit 1;
fi

# The 2 input files have the pattern:
# out_diarized/speakers/<REC>_{1,2,3}/wavs/<base>.wav

# Get the 2 input files 
a=$1
b=$2

percent_of_overlap=10

# Get the path to the wavs directory containing the input files
a_wavs_dir=$(dirname $a)
#echo "a wavs dir $a_wavs_dir"

b_wavs_dir=$(dirname $b)
#echo "b wavs dir $b_wavs_dir"

# Get the path to the directory 1 level up
a_dir=$(dirname $a_wavs_dir)
#echo "a dir $a_dir"

b_dir=$(dirname $b_wavs_dir)
#echo "b dir $b_dir"

# Get the basename of the input files 
a_base=$(basename $a .wav)
#echo "a base $a_base"

b_base=$(basename $b .wav)
#echo "b base $b_base"

# Get the speaker id
a_spk=$(basename $a_dir)
#echo " a spk $a_spk"

b_spk=$(basename $b_dir)
#echo "b spk $b_spk"

# Make a name for the directory that will contain the overlapped file
a_b_base_dir=out_diarized/overlaps/${a_spk}_${b_spk}_${a_base}_${b_base}
#echo "a b base dir $a_b_base_dir"
mkdir -p $a_b_base_dir

# Get the overlap marker
local/get_overlap_marker.pl $a $b $percent_of_overlap

# Make the name for the marker file
a_marker=$a_b_base_dir/marker.txt
#echo "a marker $a_marker"

# Make a silence buffer
local/make_silent_buffer_file.pl $a_marker

# Make a name for the silence buffer
sil=$a_b_base_dir/sil.wav
#echo "sil $sil"

# Make a name for the buffered b
buff=$a_b_base_dir/b_buff.wav
#echo "buff $buff"

# Concatenate the silent buffer with b
#echo "Concatenating $sil and $b and storing in $b_buff"
sox $sil $b $buff

# Make the name for the stereo file
stereo=$a_b_base_dir/stereo.wav
#echo "stereo $stereo"

# Make the stereo recording
#echo "Write a stereo file with $a and $buff"
sox $a $buff -c 2 $stereo -M

#Make a name for the overlapping file
overlap=$a_b_base_dir/overlap.wav
#echo "overlap $overlap"

# Merge the 2 channels by averaging the samples
#echo "Merging 2 channels of $stereo  into $overlap."
sox $stereo $overlap channels 1

# Make the name for the maxed volume file
max=$a_b_base_dir/max.wav
#echo "max $max"

# Make a name for thestats file
vc=$a_b_base_dir/vc.txt
echo "vc $vc"

# Get stats for the overlapping file
sox $overlap -n stat -v 2> $vc
echo "Getting stats."

# Write the volume maxed file
echo "Maxing volume." 
sox -v $(cat $vc) $overlap $max
exit
  b_samples=$(find $b_dir/infos -type f -name "*_samples.txt" | shuf -n 1) || break 1;
  echo "b  samples $b_samples"

  # Get the name of the directory containing the first chosen  file
  a_wavs_dir=$(dirname $a)
  #echo "a wavs dir $a_wavs_dir"

  # Get the name of the directory containing the chosen samples file
  b_info_dir=$(dirname $b_samples)
  #echo "b info dir $b_info_dir"

  # Get the name of the directory containing b
  b_dir=$(dirname $b_info_dir)
  #echo "b dir $b_dir"

  # Get the directory indicating the speaker number 
  a_dir=$(dirname $a_wavs_dir) 
  #echo "a dir $a_dir"

  # Get the basename of the first  file
  a_base=$(basename $a .wav)
  #echo "a base $a_base"

  # Get the name of the original wav file
  a=$a_dir/wavs/$a_base.wav
  #echo "a $a"

  # Get the b base
  b_base=$(basename $b_samples _samples.txt)
  #echo "b base $b_base"

  # Get the original name of b?
  b=$b_dir/wavs/$b_base.wav
  echo "b $b"

  # Make a name for the silence buffered version of b
  b_buff=$a_dir/buffs/${a_base}_${b_base}.wav
  #echo "b buff $b_buff"

  # Get the directory name for the buffered version of b
  b_buff_dir=$(dirname $b_buff)
  #echo "b buff dir $b_buff_dir"

  # Make the directory where we will store the buffered version of b
  mkdir -p $b_buff_dir


  # Get the basename of the buffered version of b
  b_buff_base=$(basename $b_buff .wav)
  #echo "b buff base $b_buff_base"

  # Make the name for the overlaps directory
  olaps_dir=$a_dir/olaps
  #echo "overlaps directory name $olaps_dir"

  # Make the directory where we will store the overlapping files
  mkdir -p $olaps_dir

  # Get the basename for c
  c_base=$(basename $c .wav)
  #echo "c base $c_base"

  # Make   # Get the basename of the overlapping file
  d_base=$(basename $d .wav)
  #echo "d base $d_base"

  # Get the name of the directory containing the overlapping files
  d_dir=$(dirname $d)
  #echo " d dir $d_dir"

  # We need to keep track of the marker for ground truth data.
  #overlap_ends_at_sample=$(cut -f 2 $b_samples)
  #overlap_begins_at_sample=$(($overlap_ends_at_sample * (100 - $percent_of_overlap) / 100))
  #echo "overlap begins at sample: $overlap_begins_at_sample"
  #echo "overlap ends at sample: $overlap_ends_at_sample"

  # Make the name for the start and end of overlap info file
  #start_and_end_of_overlap=$d_dir/${d_base}_overlap_start_and_end_markings.txt
  #echo "start edn overlap file $start_and_end_of_overlap"

  # Write the beginning and ending sample number to a file
  #echo "Write the overlap boundary markings."
  #echo "$d_dir/$d_base	$overlap_begins_at_sample	$overlap_ends_at_sample" > $start_and_end_of_overlap

  # Make a name for a directory where we will store maxed volume files
  e_dir=$a_dir/maxed_overlaps
  #echo "e dir $e_dir"

  # Make the directory the will contain the maxed overlapping files
  mkdir -p $e_dir

  # directory  to store already sampled files, sample without replacement
  mkdir -p $a_dir/sampled $b_dir/sampled

  # Move sampled file
  mv -v $a $a_dir/sampled
  mv -v $a_dir/infos/$a_base* $a_dir/sampled
  mv -v $b $b_dir/sampled
  mv -v $b_samples $b_dir/sampled
done
