#!/usr/bin/env bash

dir=$1

for f in dev-1 dev-2 train; do
    {
	while read line; do
	    line_tmp=$line
	    utt=$(echo $line | cut -d " " -f 1)
	    flac_file=$(find $dir -type f -name "*.flac" | xargs grep $tmp_line -)
	    echo "$utt sox $flac_file -t wav - remix 1 | " >> data/$f/wav.scp
	done
    } < data/$f/utt2lang;
done