#!/bin/bash

{
    while read line; do
	ft=$(file "$line")
	echo "$ft"
    done
} < data/local/wav.txt > data/local/file_type.txt

grep "mono"  data/local/file_type.txt > data/local/mono.txt
grep "stereo"  data/local/file_type.txt > data/local/stereo.txt
cut -d ":" -f 1 data/local/stereo.txt > data/local/stereo_fn.txt

