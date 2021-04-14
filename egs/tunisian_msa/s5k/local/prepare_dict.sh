#!/usr/bin/env bash

# Copyright 2017 QCRI (author: Ahmed Ali)
# Apache 2.0
# This script prepares the dictionary.

set -e
dir=data/local/dict
stage=0
. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh || exit 1;
mkdir -p $dir data/local/lexicon_data

if [ $stage -le 0 ]; then
  gale_data=GALE
  text=../../gale_arabic/s5d/data/train/text
  #[ -f $gale_data/gale_text ] && text=$gale_data/gale_text
  echo "$0:text is $text."
  [ ! -f data/local/lexicon_data/grapheme_lexicon ] ||   rm data/local/lexicon_data/grapheme_lexicon
  cat $text | cut -d ' ' -f 2- | tr -s " " "\n" | sort -u >> data/local/lexicon_data/grapheme_lexicon
fi

if [ $stage -le 1 ]; then
  echo "$0: processing lexicon text and creating lexicon... $(date)."
  # remove vowels and  rare alef wasla
  grep -hv [0-9] data/local/lexicon_data/grapheme_lexicon | \
    sed -e 's:[FNKaui\~o\`]::g' -e 's:{:}:g' | \
    sort -u > data/local/lexicon_data/processed_lexicon
fi

if [ $stage -le 2 ]; then
    echo "$0: More unnecessary dictionary preparation."
  local/prepare_lexicon.py
fi

if [ $stage -le 3 ]; then
  echo "$0: Get word list in buckwalter."
  cut -d' ' -f1 $dir/lexicon.txt > data/local/lexicon_data/words.bw
fi

if [ $stage -le 4 ]; then
  echo "$0: Get pronunciations."
  cut -d' ' -f 2- $dir/lexicon.txt > data/local/lexicon_data/prons.bw
fi

if [ $stage -le 5 ]; then
  echo "$0: Convert words to utf8."
  local/buckwalter2unicode.py -i data/local/lexicon_data/words.bw -o data/local/lexicon_data/words.txt
  mv -v $dir/lexicon.txt data/local/lexicon_data/lexicon.bw
fi

if [ $stage -le 6 ]; then
  echo "$0: Paste together words and pronunciations."
  [ ! -f $dir/lexicon_tmp.txt ] || rm $dir/lexicon_tmp.txt 
  paste -d " " data/local/lexicon_data/words.txt data/local/lexicon_data/prons.bw > $dir/lexicon_tmp.txt
fi

if [ $stage -le 7 ]; then
  echo "$0: Get non silence phone list."
  cut -d' ' -f2- $dir/lexicon_tmp.txt | sed 's/SIL//g' | tr ' ' '\n' | sort -u | sed '/^$/d' >$dir/nonsilence_phones.txt || exit 1;
fi

if [ $stage -le 8 ]; then
  echo "$0: Insert Unknown word symbol."
  echo '<UNK> UNK' >> $dir/lexicon_tmp.txt 
fi

if [ $stage -le 9 ]; then
    echo "$0: Add the unknown symbol to the list of non silence phones."
  echo UNK >> $dir/nonsilence_phones.txt
fi

if [ $stage -le 10 ]; then
  echo "$0: Add silence to lexicon."
  echo '<sil> SIL' >> $dir/lexicon_tmp.txt
fi

if [ $stage -le 11 ]; then
  echo "$0: Add sil to list of silence phones."
  echo SIL > $dir/silence_phones.txt
  echo SIL >$dir/optional_silence.txt

  echo -n "" >$dir/extra_questions.txt

  sort -u $dir/lexicon_tmp.txt > $dir/lexicon.txt
  echo "$0: Dictionary preparation succeeded"
fi
