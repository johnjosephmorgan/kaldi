#!/usr/bin/env bash

if [ $# -ne 3 ]; then
    echo "USAGE $0 <WORKDIR> <ITERATION> <NUMBER_OF_PAIRS>"
    exit 1;
fi

declare -a a
workdir=$1
i=$2
# set the number of pairs to concatenate
n=$3
sync
# find segment pairs to concatenate
a=$(find $workdir/overlaps -type f -name "max.wav" | shuf -n $n)

# check that the files exist
j=0
for m in ${a[@]}; do
  ((j++))
done

if [ ${#a[@]} -eq 0 ]; then exit 1; fi
if [ $j -le 1 ]; then exit 1; fi

# make the output directory
mkdir -p $workdir/concats/$i
# concatenate all the segments
$(sox ${a[@]} $workdir/concats/$i/overlap.wav) || exit 1;

# Concatenate rttm files
[ -f $workdir/concats/$i/pairs.txt ] && rm $workdir/concats/$i/pairs.txt;
for m in ${a[@]}; do
  markerpath=$(dirname "$m")
  rttm=$(cat "$markerpath/overlap.rttm")
  echo $rttm   >> $workdir/concats/$i/pairs.txt
done

# write list of wav file names
for m in "${a[@]}"; do
  printf '%s\n' $m > $workdir/concats/$i/wavs.txt
done

# write list of start markers
[ -f $workdir/concats/${i}_starts.txt ] && rm $workdir/concats/${i}_starts.txt;
total=0
for m in ${a[@]}; do
  markerpath=$(dirname "$m")
  start=$(cat $markerpath/segment_2_start.txt)
  ((totalsum+=total))
  ((new_start=start + totalsum))
  printf '%s\n' "$new_start" >> $workdir/concats/$i/starts.txt
  total=$(cat $markerpath/segment_2_end.txt)
done

# write list of end markers
#[ -f $workdir/concats/$i/ends.txt ] && rm $workdir/concats/$i/ends.txt;
#total=0
#totalsum=0
#for m in ${a[@]}; do
#  markerpath=$(dirname "$m")
#  end=$(cat $markerpath/end.txt)
#  ((totalsum+=total))
#  ((new_end=end + totalsum))
#  printf '%s\n' "$new_end" >> $workdir/concats/$i/ends.txt
#  total=$(cat $markerpath/total.txt)
#done

# write list of overlap durations
[ -f $workdir/concats/$i/durs.txt ] && rm $workdir/concats/$i/durs.txt;
for m in ${a[@]}; do
  markerpath=$(dirname "$m")
  dur=$(cat $markerpath/overlap_duration.txt)
  printf '%s\n' "$dur" >> $workdir/concats/$i/durs.txt
done

# write list of segment pair total durations
[ -f $workdir/concats/$i/total_segment_pair_durations.txt ] && rm $workdir/concats/$i/total_segment_pair_durations.txt;
for m in ${a[@]}; do
  markerpath=$(dirname "$m")
  total=$(cat $markerpath/segment_2_end.txt)
  printf '%s\n' "$total" >> $workdir/concats/$i/total_segment_pair_durations.txt
done

paste $workdir/concats/$i/wavs.txt $workdir/concats/$i/starts.txt $workdir/concats/$i/durs.txt > $workdir/concats/$i/segment_info.txt

# remove the process files
# We do not want to use them again
# this should implement sampling without replacement
for m in ${a[@]}; do
  [ ! -f $m ] || rm $m
done
