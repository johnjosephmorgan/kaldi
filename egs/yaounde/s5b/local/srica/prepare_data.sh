#!/bin/bash

# make acoustic model sri canada training  lists

datadir=$1

# bc stands for British Columbia
bcdir=$datadir/bc_dc_aug2016/audio/clean1/read
# qc stands for Quebec City?
qcdir=$datadir/qc_dc_aug2016/audio/clean1/read

tmpdir=data/local/tmp/srica

mkdir -p $tmpdir/lists

for x in bc qc; do
  mkdir -p $tmpdir/$x

  #get a list of the sri canada .wav files
  find \
    $datadir/${x}_dc_aug2016/audio/clean1/read -type f -name "*.wav" | \
    grep $x > $tmpdir/$x/wav_list.txt

  #  make sri canada lists
  local/srica/${x}_make_lists.pl $datadir

  utils/fix_data_dir.sh $tmpdir/$x/lists
done

# get sri canada training lists
for x in bc qc; do
  for y in wav.scp utt2spk text; do
    cat $tmpdir/$x/lists/$y >> $tmpdir/lists/$y
  done
done
