#!/usr/bin/env bash

dir=$1

for f in dev-1 dev-2 train; do
    while read line; do
	utt=$(cut -d " " -f 1 $line)
	flac_file=$(find $dir -type f -name "*.flac" | grep $line)
	echo "$utt sox $flac_file -t wav - remix 1 | " >> data/$f/wav.scp
    done
} < data/$f/utt2lang
done
  
