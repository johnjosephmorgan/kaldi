#!/bin/bash
{
    while read speakerdir; do
        all_utt2spk_entries=()
        for w in ${speakerdir}/*.wav; do
            wavname=$(basename $w ".wav")
            all_utt2spk_entries+=("${wavname} ${speakeridnumber}")
        done

        for a in "${all_utt2spk_entries[@]}"; do
            echo $a;
        done >> data/local/tmp/yaounde_utt2spk_a_unsorted.txt
	    done
} < local/src/yaounde_read_speakers_a.txt
