#!/usr/bin/env bash

declare -a a
i=$1
# set the number of pairs to concatenate
n=5
# make the output directory
mkdir -p out_diarized/concats/$i

# find segment pairs to concatenate
a=$(find out_diarized/overlaps -type f -name "max.wav" | shuf -n $n)

# check that the files exist
for m in ${a[@]}; do
  [ -f $m ] || exit 1;
done

# concatenate all the segments
$(sox ${a[@]} out_diarized/concats/$i/overlap.wav) || exit 1;

# Concatenate rttm files
[ -f out_diarized/concats/$i/pairs.txt ] && rm out_diarized/concats/$i/pairs.txt;
for m in ${a[@]}; do
  markerpath=$(dirname "$m")
  rttm=$(cat "$markerpath/overlap.rttm")
  echo $rttm   >> out_diarized/concats/$i/pairs.txt
done

# write list of wav file names
for m in "${a[@]}"; do
  printf '%s\n' $m > out_diarized/concats/$i/wavs.txt
done

# write list of start markers
[ -f out_diarized/concats/${i}_starts.txt ] && rm out_diarized/concats/${i}_starts.txt;
total=0
for m in ${a[@]}; do
  markerpath=$(dirname "$m")
  start=$(cat $markerpath/segment_2_start.txt)
  ((totalsum+=total))
  ((new_start=start + totalsum))
  printf '%s\n' "$new_start" >> out_diarized/concats/$i/starts.txt
  total=$(cat $markerpath/segment_2_end.txt)
done

# write list of end markers
#[ -f out_diarized/concats/$i/ends.txt ] && rm out_diarized/concats/$i/ends.txt;
#total=0
#totalsum=0
#for m in ${a[@]}; do
#  markerpath=$(dirname "$m")
#  end=$(cat $markerpath/end.txt)
#  ((totalsum+=total))
#  ((new_end=end + totalsum))
#  printf '%s\n' "$new_end" >> out_diarized/concats/$i/ends.txt
#  total=$(cat $markerpath/total.txt)
#done

# write list of overlap durations
[ -f out_diarized/concats/$i/durs.txt ] && rm out_diarized/concats/$i/durs.txt;
for m in ${a[@]}; do
  markerpath=$(dirname "$m")
  dur=$(cat $markerpath/overlap_duration.txt)
  printf '%s\n' "$dur" >> out_diarized/concats/$i/durs.txt
done

# write list of segment pair total durations
[ -f out_diarized/concats/$i/total_segment_pair_durations.txt ] && rm out_diarized/concats/$i/total_segment_pair_durations.txt;
for m in ${a[@]}; do
  markerpath=$(dirname "$m")
  total=$(cat $markerpath/segment_2_end.txt)
  printf '%s\n' "$total" >> out_diarized/concats/$i/total_segment_pair_durations.txt
done

paste out_diarized/concats/$i/wavs.txt out_diarized/concats/$i/starts.txt out_diarized/concats/$i/durs.txt > out_diarized/concats/$i/segment_info.txt
