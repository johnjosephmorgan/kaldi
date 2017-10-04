#!/bin/bash

# Copyright 2017 John Morgan
# Apache 2.0.

. ./cmd.sh
set -e
. ./path.sh
stage=0

. ./utils/parse_options.sh


if [ ! -d data/local/tmp/subs/lm ]; then
    mkdir -p data/local/tmp/subs/lm
fi

corpus=data/local/tmp/subs/lm/es.txt

ngram-count \
    -order 3 \
    -interpolate \
    -unk \
    -map-unk "<UNK>" \
    -limit-vocab \
    -text $corpus \
    -lm data/local/lm/subs_lm_threegram.arpa || exit 1;

    if [ -e "data/local/lm/subs_lm_threegram.arpa.gz" ]; then
	rm data/local/lm/subs_lm_threegram.arpa.gz
    fi

    gzip \
	data/local/lm/subs_lm_threegram.arpa
