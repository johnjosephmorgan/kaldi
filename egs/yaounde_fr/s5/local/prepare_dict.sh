#!/bin/bash -u

# Copyright 2018 John Morgan
# Apache 2.0.

set -o errexit

[ -f ./path.sh ] && . ./path.sh

if [ ! -d data/local/dict_nosp ]; then
  mkdir -p data/local/dict_nosp
fi

l=$1
export LC_ALL=C

cut -f2- -d " " $l | tr -s '[:space:]' '[\n*]' | grep -v SPN | \
    sort -u > data/local/dict_nosp/nonsilence_phones.txt

expand -t 1 $l | sort -u | \
    sed s/\([23456789]\)// | \
    sed s/\(1[0123456789]\)// | \
    
    sed "1d" > data/local/dict_nosp/lexicon.txt

echo "<UNK> SPN" >> data/local/dict_nosp/lexicon.txt

# silence phones, one per line.
{
    echo SIL;
    echo SPN;
} \
    > \
    data/local/dict_nosp/silence_phones.txt

echo SIL > data/local/dict_nosp/optional_silence.txt

# get the phone list from the lexicon file
(
    tr '\n' ' ' < data/local/dict_nosp/silence_phones.txt;
    echo;
    tr '\n' ' ' < data/local/dict_nosp/nonsilence_phones.txt;
    echo;
) >data/local/dict_nosp/extra_questions.txt

echo "$0: Finished dictionary preparation."
