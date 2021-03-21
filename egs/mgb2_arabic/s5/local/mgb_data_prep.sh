#!/usr/bin/env bash

if [ $# -ne 2 ]; then
  echo "Usage: $0 <DB-dir> <mer-sel>"
  exit 1;
fi

db_dir=$1
mer=$2
train_dir=data/train_mer$mer
dev_dir=data/dev

for x in $train_dir $dev_dir; do
  mkdir -p $x
  if [ -f ${x}/wav.scp ]; then
    mkdir -p ${x}/.backup
    mv $x/{wav.scp,feats.scp,utt2spk,spk2utt,segments,text} ${x}/.backup
  fi
done

find $db_dir/train/wav -type f -name "*.wav" | \
  awk -F/ '{print $NF}' | perl -pe 's/\.wav//g' > \
  $train_dir/wav_list

#Creating the train program lists
head -500 $train_dir/wav_list > $train_dir/wav_list.short

set -e -o pipefail

xmldir=$db_dir/train/xml/bw
# process xml file using python

{
  while read basename; do
    [ ! -e $xmldir/$basename.xml ] && echo "Missing $xmldir/$basename.xml" && exit 1
    local/process_xml.py $xmldir/$basename.xml - | local/add_to_datadir.py $basename $train_dir $mer
  done
} < $train_dir/wav_list;
