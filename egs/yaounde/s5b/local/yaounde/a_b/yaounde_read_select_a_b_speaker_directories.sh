#!/bin/bash
if [ -f local/src/yaounde_read_speaker_directories_a.txt ]; then
    rm local/src/yaounde_read_speaker_directories_a.txt
    fi

local/yaounde_read_get_all_speaker_directories.sh | \
    shuf | \
    tee local/src/yaounde_read_speakers_a+b.txt | \
    head \
	-n 42 > \
	local/src/yaounde_read_speakers_a.txt

tail \
    -n 42 \
    local/src/yaounde_read_speakers_a+b.txt > \
    local/src/yaounde_read_speakers_b.txt
