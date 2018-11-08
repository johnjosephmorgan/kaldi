#!/bin/bash

# Copyright 2018 John Morgan
# Apache 2.0.

# Training Data prep

if [ $# != 1 ]; then
  echo "usage: $0 <CORPUS_DIRECTORY>
example:
$0 russian/train";
  exit 1
fi

# set variables
datadir=$1/train
speech_datadir=$datadir/audio
tmpdir=data/local/tmp/ru/train
# done setting variables

mkdir -p $tmpdir
#get a list of the  .wav files
find $speech_datadir -type f -name "*.wav" > $tmpdir/wav_list.txt
#  make  lists
local/make_lists_train.pl $datadir
utils/fix_data_dir.sh $tmpdir/lists
mkdir -p data/train
for x in wav.scp utt2spk text spk2utt; do
    cp $tmpdir/lists/$x data/train/$x
done

