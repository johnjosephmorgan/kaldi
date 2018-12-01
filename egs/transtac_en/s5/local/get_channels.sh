#!/bin/bash

find /mnt/disk01/transtac_stereo -type f -name "*.wav" > data/local/stereo_basename_files.txt

{
    while  read line; do
	bn=$(basename $line)
	$(sox $line /mnt/disk01/transtac_channel_1/$bn remix 1)
	$(sox $line /mnt/disk01/transtac_channel_2/$bn remix 2)
    done
    } < data/local/stereo_basename_files.txt 
