#!/bin/bash

# Copyright 2018 John Morgan
# Apache 2.0.

# gabon read prep
yaounde_datadir=$1
datadir=$yaounde_datadir/speech/train/central_accord
tmpdir=data/local/tmp/gabonread
mkdir -p $tmpdir

#get a list of the gabon read .wav files
find $datadir -type f -name "*.wav" | grep read > $tmpdir/wav_list.txt

#  make gabon read lists
local/gabon_read/make_lists.pl $yaounde_datadir

utils/fix_data_dir.sh $tmpdir/lists
