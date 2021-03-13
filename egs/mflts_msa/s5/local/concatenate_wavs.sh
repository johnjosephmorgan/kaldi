#!/usr/bin/env bash

declare -a a
i=$1
# set the number of pairs to concatenate
n=100
# make the output directory
mkdir -p work/concats/$i

# find segment pairs to concatenate
a=$(find work/overlaps -type f -name "max.wav" | shuf -n $n)

# check that the files exist
for m in ${a[@]}; do
  [ -f $m ] || exit 1;
done

# concatenate all the segments
$(sox ${a[@]} work/concats/$i/overlap.wav) || exit 1;

# Concatenate rttm files
[ -f work/concats/$i/pairs.txt ] && rm work/concats/$i/pairs.txt;
for m in ${a[@]}; do
  markerpath=$(dirname "$m")
  rttm=$(cat "$markerpath/overlap.rttm")
  echo $rttm   >> work/concats/$i/pairs.txt
done

# write list of wav file names
for m in "${a[@]}"; do
  printf '%s\n' $m > work/concats/$i/wavs.txt
done

# write list of start markers
[ -f work/concats/${i}_starts.txt ] && rm work/concats/${i}_starts.txt;
total=0
for m in ${a[@]}; do
  markerpath=$(dirname "$m")
  start=$(cat $markerpath/segment_2_start.txt)
  ((totalsum+=total))
  ((new_start=start + totalsum))
  printf '%s\n' "$new_start" >> work/concats/$i/starts.txt
  total=$(cat $markerpath/segment_2_end.txt)
done

# write list of end markers
#[ -f work/concats/$i/ends.txt ] && rm work/concats/$i/ends.txt;
#total=0
#totalsum=0
#for m in ${a[@]}; do
#  markerpath=$(dirname "$m")
#  end=$(cat $markerpath/end.txt)
#  ((totalsum+=total))
#  ((new_end=end + totalsum))
#  printf '%s\n' "$new_end" >> work/concats/$i/ends.txt
#  total=$(cat $markerpath/total.txt)
#done

# write list of overlap durations
[ -f work/concats/$i/durs.txt ] && rm work/concats/$i/durs.txt;
for m in ${a[@]}; do
  markerpath=$(dirname "$m")
  dur=$(cat $markerpath/overlap_duration.txt)
  printf '%s\n' "$dur" >> work/concats/$i/durs.txt
done

# write list of segment pair total durations
[ -f work/concats/$i/total_segment_pair_durations.txt ] && rm work/concats/$i/total_segment_pair_durations.txt;
for m in ${a[@]}; do
  markerpath=$(dirname "$m")
  total=$(cat $markerpath/segment_2_end.txt)
  printf '%s\n' "$total" >> work/concats/$i/total_segment_pair_durations.txt
done

paste work/concats/$i/wavs.txt work/concats/$i/starts.txt work/concats/$i/durs.txt > work/concats/$i/segment_info.txt

# remove the process files
# We do not want to use them again
# this should implement sampling without replacement
for m in ${a[@]}; do
  [ -f $m ] || rm $m
done
