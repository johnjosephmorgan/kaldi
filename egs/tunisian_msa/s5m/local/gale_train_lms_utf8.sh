#!/usr/bin/env bash

help_message="Usage: $0 [options] <train-txt> <dict> <out-dir>
Train language models for GALE Arabic.\n
options: 
  --help          # print this message and exit
";

. utils/parse_options.sh

if [ $# -lt 3 ]; then
  printf "$help_message\n";
  exit 1;
fi

text=$1     # data/local/train/text
lexicon=$2  # data/local/dict/lexicon.txt
dir=$3      # data/local/lm

for f in "$text" "$lexicon"; do
  [ ! -f $x ] && echo "$0: No such file $f" && exit 1;
done

loc=`which ngram-count`;
if [ -z $loc ]; then
  if uname -a | grep 64 >/dev/null; then # some kind of 64 bit...
    sdir=`pwd`/../../../tools/srilm/bin/i686-m64 
  else
    sdir=`pwd`/../../../tools/srilm/bin/i686
  fi
  if [ -f $sdir/ngram-count ]; then
    echo Using SRILM tools from $sdir
    export PATH=$PATH:$sdir
  else
    echo You appear to not have SRILM tools installed, either on your path,
    echo or installed in $sdir.  See tools/install_srilm.sh for installation
    echo instructions.
    exit 1
  fi
fi

stage=0

set -o errexit
mkdir -p $dir
export LC_ALL=C 

heldout_sent=10000
cut -d' ' -f2- $text | gzip -c > $dir/train.all.gz
cut -d' ' -f2- $text | tail -n +$heldout_sent | gzip -c > $dir/train.gz
cut -d' ' -f2- $text | head -n $heldout_sent > $dir/heldout

# convert the heldout to utf8
local/buckwalter2unicode.py \
  -i $dir/heldout \
  -o $dir/heldout_utf8.txt 

cut -d' ' -f1 $lexicon > $dir/wordlist

# convert the training text to utf8
gunzip   $dir/train.gz 
local/buckwalter2unicode.py \
  -i $dir/train \
  -o $dir/train_utf8.txt

gzip $dir/train_utf8.txt

if [ $stage -le 1 ]; then
  # Trigram language model
  echo "training tri-gram lm"
  smoothing="kn"
  ngram-count \
    -text $dir/train_utf8.txt.gz \
    -order 3 \
    -limit-vocab -vocab $dir/wordlist.txt \
    -unk -map-unk "<UNK>" \
    -${smoothing}discount -interpolate \
    -lm $dir/gale.o3g.${smoothing}_utf8.gz
  echo "PPL for GALE Arabic trigram LM:"
  ngram \
    -unk \
    -lm $dir/gale.o3g.${smoothing}_utf8.gz \
    -ppl $dir/heldout_utf8.txt
  ngram \
    -unk \
    -lm $dir/gale.o3g.${smoothing}_utf8.gz \
    -ppl $dir/heldout_utf8.txt \
    -debug 2 >& $dir/3gram.${smoothing}_utf8.ppl2
  # 4gram language model
  echo "training 4-gram lm"
  ngram-count \
    -text $dir/train_utf8.txt.gz \
    -order 4 \
    -limit-vocab \
    -vocab $dir/wordlist.txt \
    -unk -map-unk "<UNK>" \
    -${smoothing}discount -interpolate \
    -lm $dir/gale.o4g.${smoothing}_utf8.gz
  echo "PPL for GALE Arabic 4gram LM:"
  ngram \
    -unk \
    -lm $dir/gale.o4g.${smoothing}_utf8.gz \
    -ppl $dir/heldout_utf8.txt
  ngram \
    -unk \
    -lm $dir/gale.o4g.${smoothing}_utf8.gz \
    -ppl $dir/heldout_utf8.txt \
    -debug 2 >& $dir/4gram.${smoothing}_utf8.ppl2
fi
