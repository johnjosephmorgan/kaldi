#!/usr/bin/env bash

declare -a a
i=$1
# make the output directory
mkdir -p out_diarized/concats/$i

# find segment pairs to concatenate
a=$(find out_diarized/overlaps -type f -name "max.wav" | shuf -n 100)

# check that the files exist
for m in ${a[@]}; do
  [ -f $m ] || exit 1;
done

# concatenate all the segments
$(sox ${a[@]} out_diarized/concats/$i/overlap.wav)

# write list of wav file names
for m in "${a[@]}"; do
  printf '%s\n' $m > out_diarized/concats/$i/wavs.txt
done

# write list of start markers
[ -f out_diarized/concats/${i}_starts.txt ] && rm out_diarized/concats/${i}_starts.txt;
total=0
for m in ${a[@]}; do
  markerpath=$(dirname "$m")
  start=$(cat $markerpath/start.txt)
  ((totalsum+=total))
  ((new_start=start + totalsum))
  printf '%s\n' "$new_start" >> out_diarized/concats/$i/starts.txt
  total=$(cat $markerpath/total.txt)
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

# write list of durations
[ -f out_diarized/concats/$i/durations.txt ] && rm out_diarized/concats/$i/durations.txt;
total=0
totalsum=0
for m in ${a[@]}; do
  markerpath=$(dirname "$m")
  dur=$(cat $markerpath/overlap_duration.txt)
  ((totalsum+=total))
  ((new_dur=dur + totalsum))
  printf '%s\n' "$new_dur" >> out_diarized/concats/$i/durs.txt
  total=$(cat $markerpath/total.txt)
done

paste out_diarized/concats/$i/wavs.txt out_diarized/concats/$i/starts.txt out_diarized/concats/$i/durs.txt > out_diarized/concats/$i/boundaries.txt
#rm ${a[@]}
