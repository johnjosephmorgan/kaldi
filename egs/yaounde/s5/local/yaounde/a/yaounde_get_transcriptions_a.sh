#!/bin/bash
{
    while read speakernumber; do
	$(cat data/prompts/${speakernumber}/prompts >> data/local/tmp/yaounde_trans_a_unsorted.txt)
    done
} < data/local/tmp/yaounde_all_speakers_a.txt
