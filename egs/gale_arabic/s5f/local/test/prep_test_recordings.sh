#!/usr/bin/env bash

if [ $# -ne 1 ]; then
  echo "USAGE: $0 <SRC_DIR>"
  exit 1;
fi

srcdir=$1
# process the Libyan MSA data
tmpdir=data/local/tmp
tmp_libyan=$tmpdir/libyan
datadir=srcdir_dir/Tunisian_MSA/data
# location of test data 
libyan_src=$datadir/speech/test/Libyan_MSA

mkdir -p $tmp_libyan
for s in cls lfi srj; do
  mkdir -p $tmp_libyan/$s
  # get list of  wav files
  find $libyan_src/$s -type f \
    -name "*.wav" \
    | grep recordings > $tmp_libyan/$s/recordings_wav.txt

  echo "$0: making recordings list for $s"
  local/test_recordings_make_lists.pl \
    $libyan_src/$s/data/transcripts/recordings/${s}_recordings.tsv $s libyan
done

# process the Tunisian MSA test data

mkdir -p $tmp_tunis/mbt

# get list of  wav files
find $data_dir/speech/test/mbt -type f \
  -name "*.wav" \
  | grep recordings > $tmp_tunis/mbt/recordings_wav.txt

echo "$0: making recordings list for mbt"
local/test_recordings_make_lists.pl \
  $data_dir/transcripts/test/mbt/recordings/mbt_recordings.tsv mbt tunis

mkdir -p data/test
# get the Libyan files
for s in cls lfi srj; do
  for x in wav.scp utt2spk text; do
    cat     $tmp_libyan/$s/recordings/$x | tr "	" " " >> data/test/$x
  done
done

for x in wav.scp utt2spk text; do
  cat     $tmp_tunis/mbt/recordings/$x | tr "	" " " >> data/test/$x
done

utils/utt2spk_to_spk2utt.pl data/test/utt2spk | sort > data/test/spk2utt

utils/fix_data_dir.sh data/test
