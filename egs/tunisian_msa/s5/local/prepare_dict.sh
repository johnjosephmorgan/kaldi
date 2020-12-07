#!/bin/bash -u

# Copyright 2018 John Morgan
# Apache 2.0.

set -o errexit

[ -f ./path.sh ] && . ./path.sh

if [ ! -d data/local/dict ]; then
  mkdir -p data/local/dict
fi

lx=$1
tmp_lx=data/local/tmp/dict/lexicon.txt
export LC_ALL=C
# map dollar sign to S
tr \$ S < $lx > $tmp_lx

cut -f2- -d " " $tmp_lx | tr -s '[:space:]' '[\n*]' | grep -v SPN | \
    sort -u > data/local/dict/nonsilence_phones.txt

expand -t 1 $tmp_lx | sort -u | \
    sed "1d" > data/local/dict/lexicon.txt

echo "<UNK> SPN" >> data/local/dict/lexicon.txt

# silence phones, one per line.
{
    echo SIL;
    echo SPN;
} \
    > \
    data/local/dict/silence_phones.txt

echo SIL > data/local/dict/optional_silence.txt

# get the phone list from the lexicon file
(
    tr '\n' ' ' < data/local/dict/silence_phones.txt;
    echo;
    tr '\n' ' ' < data/local/dict/nonsilence_phones.txt;
    echo;
) >data/local/dict/extra_questions.txt

echo "$0: Finished dictionary preparation."
