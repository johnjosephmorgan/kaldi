#!/usr/bin/env bash

help_message="Usage: $0 [options] <train-txt> <dict> <out-dir>
Train language models with GALE Arabic and ARL.\n
options: 
  --help          # print this message and exit
";

. utils/parse_options.sh

text=data/local/lm/training_text.txt
lexicon=../../gale_arabic/s5d/data/local/dict/lexicon.txt \
dir=data/local/lm

[ ! -f $text ] && echo "$0: No such file $text" && exit 1;
[ ! -f $lexicon ] && echo "$0: No such file $lexicon" && exit 1;

loc=$(which ngram-count);
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
cut -d' ' -f2- $text | gzip -c > $dir/train.gale.gz
cut -d' ' -f2- $text | tail -n +$heldout_sent | gzip -c > $dir/train_gale.gz
cut -d' ' -f2- $text | head -n $heldout_sent > $dir/heldout_gale

# convert the heldout to utf8
local/buckwalter2unicode.py \
  -i $dir/heldout_gale \
  -o $dir/heldout_gale_utf8.txt 

cut -d' ' -f1 $lexicon > $dir/wordlist_gale

# convert the wordlist to utf8
local/buckwalter2unicode.py \
  -i $dir/wordlist_gale \
  -o $dir/wordlist_gale_utf8.txt

# convert the training text to utf8
gunzip   $dir/train_gale.gz 
local/buckwalter2unicode.py \
  -i $dir/train_gale \
  -o $dir/train_gale_utf8.txt

cat $dir/train_gale_utf8.txt data/local/lm/training_arl.txt > data/local/lm/train_gale_arl_utf8.txt
gzip $dir/train_gale_arl_utf8.txt

if [ $stage -le 1 ]; then
  # Trigram language model
  echo "training tri-gram lm"
  smoothing="kn"
  ngram-count \
    -text $dir/train_gale_arl_utf8.txt.gz \
    -order 3 \
    -limit-vocab -vocab $dir/wordlist_gale_utf8.txt \
    -unk -map-unk "<UNK>" \
    -${smoothing}discount -interpolate -lm \
    $dir/gale_arl.o3g.${smoothing}_utf8.gz
  echo "PPL for GALE ARL Arabic trigram LM:"
  ngram \
    -unk \
    -lm $dir/gale_arl.o3g.${smoothing}_utf8.gz \
    -ppl $dir/heldout_gale_arl_utf8.txt
  ngram -unk -lm \
    $dir/gale_arl.o3g.${smoothing}_utf8.gz \
    -ppl $dir/heldout_utf8.txt \
    -debug 2 >& $dir/3gram.${smoothing}_gale_arl_utf8.ppl2
  # 4gram language model
  echo "training 4-gram GALE ARL lm"
  ngram-count \
    -text $dir/train_gale_arl_utf8.txt.gz \
    -order 4 \
    -limit-vocab -vocab $dir/wordlist_gale_utf8.txt \
    -unk -map-unk "<UNK>" -${smoothing}discount -interpolate -lm \
    $dir/gale_arl.o4g.${smoothing}_utf8.gz
  echo "PPL for GALE ARL Arabic 4gram LM:"
  ngram \
    -unk \
    -lm $dir/gale_arl.o4g.${smoothing}_utf8.gz \
    -ppl $dir/heldout_gale_arl_utf8.txt
  ngram \
    -unk \
    -lm $dir/gale_arl.o4g.${smoothing}_utf8.gz \
    -ppl $dir/heldout_gale_arl_utf8.txt \
    -debug 2 >& $dir/4gram.${smoothing}_gale_arl_utf8.ppl2
fi
