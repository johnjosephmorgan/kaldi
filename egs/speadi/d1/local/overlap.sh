#!/usr/bin/env bash

if [ $# -ne 3 ]; then
  echo "UsAGE: $0 <WORK DIR> <FLAC_FILE_1> <FLAC_FILE_2>";
    exit 1;
fi

workdir=$1

# The 2 input files have the pattern:
# $workdir/samples/<REC>_{1,2,3}/<base>_samples.txt

# Get the 2 input files 
a=$2
b=$3

percent_of_overlap=5

# Get the path to the speaker directory containing the input files
a_spk_dir=$(dirname $a)
#echo "a spk dir $a_spk_dir"

b_spk_dir=$(dirname $b)
#echo "b spk dir $b_spk_dir"

# Get the basename of the input files 
a_base=$(basename $a _samples.txt)
#echo "a base $a_base"

b_base=$(basename $b _samples.txt)
#echo "b base $b_base"

# Get the speaker id
a_spk=$(basename $a_spk_dir)
#echo " a spk $a_spk"

b_spk=$(basename $b_spk_dir)
#echo "b spk $b_spk"

# Make a name for the directory that will contain the overlapped file
a_b_base_dir=$workdir/overlaps/${a_spk}_${b_spk}_${a_base}_${b_base}
#echo "a b base dir $a_b_base_dir"
mkdir -p $a_b_base_dir

# We need to pass the wav file to the marker script
a_wav=$workdir/speakers/$a_spk/$a_base.wav
#echo "a wav $a_wav"

b_wav=$workdir/speakers/$b_spk/$b_base.wav
#echo "b wav $b_wav"

# check that the wav files exist
[ -f $a_wav ] || exit 1;
[ -f $b_wav ] || exit 1;

# Get the overlap endpoint markers and the total length
local/get_overlap_marker.pl $workdir $a_wav $b_wav $percent_of_overlap

# Piece  together the name of the  rttm files
a_rttm=$a_b_base_dir/segment_1.rttm
#echo "a rttm $a_rttm"

# Check that the first rttm file exists
[ -f $a_rttm ] || exit 1;

b_rttm=$a_b_base_dir/segment_2.rttm
#echo "b rttm $b_rttm"

# Check that the second rttm file exists
[ -f $b_rttm ] || exit 1;

# make a name for the concatenation of the 2 rttm files
a_b_rttm=$a_b_base_dir/overlap.rttm

# concatenate the 2 rttm files
a_b_rttm=$(cat $a_rttm $b_rttm > $a_b_rttm)

# Check that the concatenation of rttm files exists
[ -f $a_b_rttm ] || exit 1;

# Piece  together the name of the start marker file
a_start=$a_b_base_dir/segment_2_start.txt
#echo "a start $a_start"

# Check that the start marker file exists
[ -f $a_start ] || exit 1;

# Make a silence buffer
local/make_silent_buffer_file.pl $a_start

# Make a name for the silence buffer
sil=$a_b_base_dir/sil_seconds.wav
#echo "sil $sil"

# Make a name for the buffered b
buff=$a_b_base_dir/buff.wav
#echo "buff $buff"

# Concatenate the silent buffer with b
#echo "Concatenating $sil and $b_wav and storing in $buff"
sox $sil $b_wav $buff

# Make the name for the stereo file
stereo=$a_b_base_dir/stereo.wav
#echo "stereo $stereo"

# Make the stereo recording
#echo "Write a stereo file with $a_wav and $buff"
sox $a_wav $buff -c 2 $stereo -M

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
#echo "vc $vc"

# Get stats for the overlapping file
sox $overlap -n stat -v 2> $vc
#echo "Getting stats."

# Write the volume maxed file
#echo "Maxing volume." 
sox -v $(cat $vc) $overlap $max
exit
# clean up
for f in $buff $overlap $stereo $vc; do
  rm $f
done
