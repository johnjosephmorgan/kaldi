#!/usr/bin/env bash

dir=$1

for f in dev-1 dev-2 train; do
  if [ -f data/$f/flac.txt ]; then
    rm data/$f/flac.txt
  fi
  {
    while read line; do
      find $dir -type f -name "${line}.flac" >> data/$f/flac.txt
    done
  } < data/$f/utt.txt ;
done
