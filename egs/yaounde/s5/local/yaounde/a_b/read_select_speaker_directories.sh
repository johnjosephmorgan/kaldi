#!/bin/bash
wav_home=/mnt/corpora/Yaounde/read/wavs/16000
tmpdir=data/local/tmp/yaounde

find $wav_home -mindepth 1 -maxdepth 1 -type d | shuf | tee $tmpdir/read_speakers_a+b.txt | head -n 42 > $tmpdir/read_speakers_a.txt

tail -n 42 $tmpdir/read_speakers_a+b.txt > $tmpdir/read_speakers_b.txt
