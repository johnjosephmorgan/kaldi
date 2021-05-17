#!/bin/bash

# niger prep
datadir=$1
tmpdir=data/local/tmp/niger
mkdir -p $tmpdir

#get a list of the niger .wav files
find $datadir -type f -name "*.wav" > $tmpdir/wav_list.txt

#  make niger lists
local/niger/make_lists.pl $datadir

utils/fix_data_dir.sh $tmpdir/lists
