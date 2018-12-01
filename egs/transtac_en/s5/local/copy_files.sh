#!/bin/bash

{
    while read line; do
	bn=$(basename "$line")
	cp "$line" /mnt/disk01/transtac_stereo/$bn
    done
} < data/local/stereo_fn.txt

