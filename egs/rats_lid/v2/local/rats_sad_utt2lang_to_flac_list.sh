#!/usr/bin/env bash

dir=$1

for f in dev-1 dev-2 train; do
    cut -d " " -f 1 data/$f/utt2lang > data/$f/utt.txt
done


for f in dev-1 dev-2 train; do
    {
	while read line; do
	    find $dir -type f -name "${line}.flac"
	done
    } < data/$f/utt.txt  >> data/$f/flac.txt;
done
