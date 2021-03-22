#!/bin/bash

# gabon read prep
datadir=$1

tmpdir=data/local/tmp/gabonread
mkdir -p $tmpdir

#get a list of the gabon read .wav files
find $datadir -type f -name "*.wav" | grep read > $tmpdir/wav_list.txt

#  make gabon read lists
local/gabon_read/make_lists.pl $datadir

utils/fix_data_dir.sh $tmpdir/lists
