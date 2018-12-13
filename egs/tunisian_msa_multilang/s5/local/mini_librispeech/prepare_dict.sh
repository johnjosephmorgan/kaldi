#!/bin/bash -u

# Copyright 2018 John Morgan
# Apache 2.0.

set -o errexit

[ -f ./path.sh ] && . ./path.sh

dir=$1
tmpdir=data/local/tmp
cmudict_dir=$tmpdir/cmudic
cmudict_plain=$tmpdir/cmudict.0.7a.plain

if [ ! -d $dir ]; then
  mkdir -p $dir
fi


export LC_ALL=C

mkdir -p $cmudict_dir
svn co -r 12440 https://svn.code.sf.net/p/cmusphinx/code/trunk/cmudict $cmudict_dir || exit 1;
echo "Removing the pronunciation variant markers ..."
grep -v ';;;' $cmudict_dir/cmudict.0.7a | \
  perl -ane 'if(!m:^;;;:){ s:(\S+)\d+:$1 :g; print; }' \
  | tr -d ")" | tr -s " " > $cmudict_plain || exit 1;

cut -f2- -d " " $cmudict_plain | tr -s '[:space:]' '[\n*]' | grep -v SPN | \
    sort -u > $dir/nonsilence_phones.txt

sort -u $cmudict_plain  | \
    sed s/\([23456789]\)// | \
    sed s/\(1[0123456789]\)// | \
    sort -u > $dir/lexicon.txt

# silence phones, one per line.
{
    echo SIL;
    echo SPN;
} \
    > \
    $dir/silence_phones.txt

echo SIL > $dir/optional_silence.txt

# get the phone list from the lexicon file
(
    tr '\n' ' ' < $dir/silence_phones.txt;
    echo;
    tr '\n' ' ' < $dir/nonsilence_phones.txt;
    echo;
) >$dir/extra_questions.txt

echo "$0: Finished dictionary preparation."
