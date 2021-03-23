#!/bin/bash

# Copyright 2017 John Morgan
# Apache 2.0.

. ./cmd.sh
set -e
. ./path.sh
stage=0

. ./utils/parse_options.sh

if [ ! -d data/local/lm ]; then
    mkdir -p data/local/lm
fi

# use only training prompts
cut -f 2 data/train/text > data/local/lm/training_text.txt
# append  dev text
cut -f 2 data/dev/text >> data/local/lm/training_text.txt
# append eval text
cut -f 2 data/eval/text >> data/local/lm/training_text.txt

corpus=data/local/lm/training_text.txt

ngram-count \
    -order 3 \
    -interpolate \
    -unk \
    -map-unk "<UNK>" \
    -limit-vocab \
    -text $corpus \
    -lm data/local/lm/threegram.arpa || exit 1;

if [ -e "data/local/lm/threegram.arpa.gz" ]; then
    rm data/local/lm/threegram.arpa.gz
fi

gzip \
    data/local/lm/threegram.arpa
