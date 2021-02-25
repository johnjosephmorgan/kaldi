#!/usr/bin/env bash

for s in out_diarized/speakers/*; do
  for f in $s/wavs/*.wav; do
    base=$(basename $f .wav)
    wavsdir=$(dirname $f)
    dir=$(dirname $wavsdir)
    [ -d $dir/infos ] || mkdir -p $dir/infos;
    sox --i $f | egrep "Input|Duration" > $dir/infos/${base}_info.txt
    cat $dir/infos/${base}_info.txt | grep Duration | cut -d "=" -f 2 | cut -d "~" -f 1 | cut -d " " -f 2 > $dir/infos/${base}_duration.txt
    cat $dir/infos/${base}_info.txt | grep "Input" | cut -d ":" -f 2 | tr -d "'" > $dir/infos/${base}_filename.txt
    paste $dir/infos/${base}_filename.txt $dir/infos/${base}_duration.txt > $dir/infos/${base}_samples.txt
  done
done
