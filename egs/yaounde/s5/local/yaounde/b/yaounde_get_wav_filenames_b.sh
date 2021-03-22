#!/bin/bash
{
while read line; do
find \
    $line \
     -type f \
     -name "*.wav"
done
} < local/src/yaounde_read_speakers_b.txt > 	 data/local/tmp/yaounde_wav_filenames_b.txt


