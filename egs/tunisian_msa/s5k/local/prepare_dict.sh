#!/usr/bin/env bash

# Copyright 2017 QCRI (author: Ahmed Ali)
# Apache 2.0
# This script prepares the dictionary.

set -e
dir=data/local/dict
lexicon_url1="http://alt.qcri.org//resources/speech/dictionary/ar-ar_grapheme_lexicon_2016-02-09.bz2";
lexicon_url2="http://alt.qcri.org//resources/speech/dictionary/ar-ar_lexicon_2014-03-17.txt.bz2";
stage=0
. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh || exit 1;
mkdir -p $dir data/local/lexicon_data

if [ $stage -le 0 ]; then
  gale_data=GALE
  text=../../gale_arabic/s5d/data/train/text
  #[ -f $gale_data/gale_text ] && text=$gale_data/gale_text
  echo "text is $text"
  cat $text | cut -d ' ' -f 2- | tr -s " " "\n" | sort -u >> data/local/lexicon_data/grapheme_lexicon
fi

if [ $stage -le 1 ]; then
  echo "$0: processing lexicon text and creating lexicon... $(date)."
  # remove vowels and  rare alef wasla
  grep -v [0-9] data/local/lexicon_data/grapheme_lexicon |  sed -e 's:[FNKaui\~o\`]::g' -e 's:{:}:g' | sort -u > data/local/lexicon_data/processed_lexicon
  local/prepare_lexicon.py
fi

cut -d' ' -f1 $dir/lexicon.txt > data/local/lexicon_data/words.bw
cut -d' ' -f 2- $dir/lexicon.txt > data/local/lexicon_data/prons.bw
local/buckwalter2unicode.py -i data/local/lexicon_data/words.bw -o data/local/lexicon_data/words.txt
mv $dir/lexicon.txt data/local/lexicon_data/lexicon.bw
paste -d " " data/local/lexicon_data/words.txt data/local/lexicon_data/prons.bw > $dir/lexicon.txt
cut -d' ' -f2- $dir/lexicon.txt | sed 's/SIL//g' | tr ' ' '\n' | sort -u | sed '/^$/d' >$dir/nonsilence_phones.txt || exit 1;

sed -i '1i<UNK> UNK' $dir/lexicon.txt
echo UNK >> $dir/nonsilence_phones.txt

echo '<sil> SIL' >> $dir/lexicon.txt

echo SIL > $dir/silence_phones.txt

echo SIL >$dir/optional_silence.txt

echo -n "" >$dir/extra_questions.txt

echo "$0: Dictionary preparation succeeded"
