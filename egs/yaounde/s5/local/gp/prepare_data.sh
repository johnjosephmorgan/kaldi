#!/bin/bash
# global phone data prep

gp_corpus=$1

tmpdir=data/local/tmp/gp

mkdir -p $tmpdir

# get list of globalphone .wav files
find $gp_corpus/French/adc/wav -type f -name "*.wav" > $tmpdir/wav_list.txt

# make gp training lists
local/gp/make_lists.pl $gp_corpus/French/adc/wav

utils/fix_data_dir.sh $tmpdir/lists
