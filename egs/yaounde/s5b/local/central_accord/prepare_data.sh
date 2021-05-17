#!/bin/bash

# ca16 test prep
datadir=$1
tmpdir=data/local/tmp/centralaccord
mkdir -p $tmpdir

#get a list of the ca16 .wav files
find $datadir -type f -name "*.wav" > $tmpdir/wav_list.txt

#  make ca16 lists
local/central_accord/make_lists.pl $datadir

utils/fix_data_dir.sh $tmpdir/lists

mkdir -p data/ca16

for x in spk2utt text utt2spk wav.scp; do
  cp $tmpdir/lists/$x data/ca16/
done
