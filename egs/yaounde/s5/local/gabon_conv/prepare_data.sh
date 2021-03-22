#!/bin/bash

datadir=$1

tmpdir=data/local/tmp/gabonconv
mkdir -p $tmpdir

find $datadir -type f -name "*.wav" | grep  conv > $tmpdir/wav_list.txt

local/gabon_conv/make_lists.pl $datadir

utils/utt2spk_to_spk2utt.pl $tmpdir/lists/

utils/fix_data_dir.sh $tmpdir/lists
