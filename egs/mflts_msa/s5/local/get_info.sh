#!/usr/bin/env bash

if [ ! -d out_diarized/tmp ]; then
    mkdir -p out_diarized/tmp
fi

if [ -f out_diarized/tmp/info.txt ]; then
  rm out_diarized/tmp/info.txt
fi

for r in out_diarized/work/*; do
  for s in $r/audio_threshold/*; do
    for f in $s/*; do
      sox --i $f | egrep "Input|Duration" >> out_diarized/tmp/info.txt
    done
  done
done

cat out_diarized/tmp/info.txt | grep Duration | cut -d "=" -f 2 | cut -d "~" -f 1 | cut -d " " -f 2 > out_diarized/tmp/durations.txt
cat out_diarized/tmp/info.txt | grep "Input" | cut -d ":" -f 2 | tr -d "'" > out_diarized/tmp/filenames.txt
paste out_diarized/tmp/filenames.txt out_diarized/tmp/durations.txt > out_diarized/tmp/samples.txt
