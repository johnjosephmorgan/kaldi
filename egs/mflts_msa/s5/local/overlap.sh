#!/usr/bin/env bash

if [ $# -ne 1 ]; then
    echo "UsAGE: $0 <ITERATION>";
    exit 1;
fi

i=$1
percent_of_overlap=20

a_dir=out_diarized/work/$i
j=$(($i + 1))
mkdir -p  $a_dir $b_dir

for r in $a_dir/*; do
    for s in $r/audio_threshold/*; do
    # Get the name of a randomly chosen file 
    a=$(find $s/wavs/* -type f -name "*.wav" | shuf -n 1)
    #echo "a $a"

    # get the name of another randomly chosen file from the samples files
    k=$(basename $s)
    l=$(($k + 1))
    t=$(dirname $s)
    b_dir=$t/$l
    [ ! -d $b_dir ] && break 2;
   b_samples=$(find $b_dir/infos -type f -name "*_samples.txt" | shuf -n 1)
    #echo "b  samples $b_samples"

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
    #echo "b $b"

    # Make a directory where we will store themarker
    a_marks_dir=$a_dir/marks
    mkdir -p $a_marks_dir
    #echo "a marks dir $a_marks_dir"

    # Get the overlap marker
    local/get_overlap_marker.pl $a $b $percent_of_overlap

    # Make the name for the marker file
    a_marker=$a_marks_dir/${a_base}_marker.txt
    #echo "a marker $a_marker"

    # Make a silence buffer
    local/make_silent_buffer_file.pl $a_marker

    # Make a name for the directory containing silence files
    a_sil_dir=$a_dir/sils
    #echo "a sil dir $a_sil_dir";

    # Make a name for the silence buffer file make from a
    a_sil=$a_sil_dir/$a_base.wav
    #echo "a sil $a_sil"

    # Make a name for the silence buffered version of b
    b_buff=$a_dir/buffs/${a_base}_${b_base}.wav
    #echo "b buff $b_buff"

    # Get the directory name for the buffered version of b
    b_buff_dir=$(dirname $b_buff)
    #echo "b buff dir $b_buff_dir"

    # Make the directory where we will store the buffered version of b
    mkdir -p $b_buff_dir

    # Concatenate the silent buffer with b
    #echo "Concatenating $a_sil and $b and storing in $b_buff"
    sox $a_sil $b $b_buff

    # Get the basename of the buffered version of b
    b_buff_base=$(basename $b_buff .wav)
    #echo "b buff base $b_buff_base"

    # Make the name for the stereos directory
    stereos=$a_dir/stereos
    #echo "stereos $stereos"

    # Make the directory where we will store the stereo files
    mkdir -p $stereos

    # Make the name for the stereo file
    c=$stereos/$b_buff_base.wav
    #echo "c $c"

    # Make the stereo recording
    #echo "Write a stereo file with $a and $b_buff"
    sox $a $b_buff -c 2 $c -M

    # Make the name for the overlaps directory
    olaps_dir=$a_dir/olaps
    #echo "overlaps directory name $olaps_dir"

    # Make the directory where we will store the overlapping files
    mkdir -p $olaps_dir

    # Get the basename for c
    c_base=$(basename $c .wav)
    #echo "c base $c_base"

    # Make a name for the overlapping file
    d=$olaps_dir/${c_base}.wav
    #echo "d $d"

    # Merge the 2 channels by averaging the samples
    #echo "Merging $c and $d."
    sox $c $d channels 1

    # Get the basename of the overlapping file
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

    # Make the name for the maxed volume file
    e=$e_dir/$d_base.wav
    #echo "e $e"

    # Make a name for thestats file
    vc_name=$e_dir/${d_base}_vc.txt
    #echo "vc name $vc_name"

    # Get stats for the overlapping file
    sox $d -n stat -v 2> $vc_name
    #echo "Getting stats."

    # Write the volume maxed file
    #echo "Maxing volume." 
    sox -v $(cat $vc_name) $d $e
  done
done
