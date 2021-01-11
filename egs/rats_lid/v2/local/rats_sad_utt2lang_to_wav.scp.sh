#!/usr/bin/env bash

dir=$1

for f in dev-1 dev-2 train; do
    cut -d " " -f 1 data/$f/utt2lang > data/$f/utt.txt
done


for f in dev-1 dev-2 train; do
    {
	while read line; do
	    flacfile=$(find $dir -type f -name "\${line}.flac\")
	    echo "$line sox ${flacfile} -t wav - remix 1 | " >> data/$f/wav.scp
	done
    } < data/$f/utt.txt;
done
