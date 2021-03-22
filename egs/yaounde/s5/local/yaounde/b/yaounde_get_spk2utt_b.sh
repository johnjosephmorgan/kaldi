#!/bin/bash

{
    while read speakeridnumber; do
	DATA=$(dirname $speakeridnumber)
	speakerdir="${DATA}/$speakeridnumber"
        all_spk2utt_entries=()
	            all_spk2utt_entries+=("${speakeridnumber} ")
        for w in ${speakerdir}/*.wav; do
            wavname=$(basename $w ".wav")
            all_spk2utt_entries+=("${wavname}")
        done

        for a in "${all_spk2utt_entries[@]}"; do
            echo -n "$a ";
        done >> data/local/tmp/yaounde_spk2utt_b_unsorted.txt
    echo "" >> data/local/tmp/yaounde_spk2utt_b_unsorted.txt
    done
} < data/local/tmp/yaounde_wav_filenames_b.txt
