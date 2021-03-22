#!/bin/bash
{
    while read speakernumber; do
	$(cat data/prompts/${speakernumber}/prompts >> data/local/tmp/yaounde_trans_b_unsorted.txt)
    done
} < data/local/tmp/yaounde_all_speakers_b.txt
