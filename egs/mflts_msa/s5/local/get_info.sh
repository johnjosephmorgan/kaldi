#!/usr/bin/env bash

if [ ! -d tmp ]; then
    mkdir -p tmp
fi

if [ -f info.txt ]; then
  rm tmp/info.txt
fi

for r in out_dirized/*; do
    for s in $r/audio_threshold/*; do
	for f in $s/*; do
	    sox --i $f | egrep "Input|Duration" >> tmp/info.txt
	done
    done
done

cat tmp/info.txt | grep Duration | cut -d "=" -f 2 | cut -d "~" -f 1 | cut -d " " -f 2 > tmp/durations.txt
cat tmp/info.txt | grep "Input" | cut -d ":" -f 2 | tr -d "'" > tmp/filenames.txt
paste tmp/filenames.txt tmp/durations.txt > tmp/samples.txt
