#!/usr/bin/env bash

datadir=/mnt/corpora/LDC2015S02/RATS_SAD/data

local/rats_sad_get_filenames.sh $datadir

for f in dev-1 dev-2 train; do
    local/rats_sad_data_prep.pl data/local/annotations/$f.txt
done

local/rats_sad_utt2lang_to_wav.scp.sh $datadirr
