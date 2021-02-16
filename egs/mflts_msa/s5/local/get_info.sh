#!/usr/bin/env bash

mkdir -p out_diarized/tmp

for r in out_diarized/work/*; do
  for s in $r/audio_threshold/*; do
    for f in $s/*; do
      sox --i $f | egrep "Input|Duration" >> out_diarized/tmp/info.txt
      base=$(basename $f .wav)
      dir=$(dirname $f)
      sox --i $f | egrep "Input|Duration" > $dir/${base}_info.txt
      cat $dir/${base}_info.txt | grep Duration | cut -d "=" -f 2 | cut -d "~" -f 1 | cut -d " " -f 2 > $dir/${base}_duration.txt
      cat $dir/${base}_info.txt | grep "Input" | cut -d ":" -f 2 | tr -d "'" > $dir/${base}_filename.txt
      paste $dir/${base}_filename.txt $dir/${base}_duration.txt > $dir/${base}_samples.txt
    done
  done
done

cat out_diarized/tmp/info.txt | grep Duration | cut -d "=" -f 2 | cut -d "~" -f 1 | cut -d " " -f 2 > out_diarized/tmp/durations.txt
cat out_diarized/tmp/info.txt | grep "Input" | cut -d ":" -f 2 | tr -d "'" > out_diarized/tmp/filenames.txt
paste out_diarized/tmp/filenames.txt out_diarized/tmp/durations.txt > out_diarized/tmp/samples.txt
